import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import '../../domain/entities/transcription.dart';
import '../ai/native/whisper_bindings.dart';
import '../ai/native/whisper_platform_service.dart';
import '../ai/native/llama_bindings.dart';
import '../ai/ai_state.dart';

/// Stream controller para atualizações de transcrição
class TranscriptionProgress {
  final String? partialText;
  final List<SpeakerSegment>? speakerSegments;
  final double progress;
  final bool isComplete;
  final String? statusMessage;

  TranscriptionProgress({
    this.partialText,
    this.speakerSegments,
    this.progress = 0.0,
    this.isComplete = false,
    this.statusMessage,
  });

  static TranscriptionProgress empty() => TranscriptionProgress(progress: 0.0, statusMessage: 'Iniciando...');
  static TranscriptionProgress loading(double progress, String message) => TranscriptionProgress(progress: progress, statusMessage: message);
  static TranscriptionProgress complete(String text, List<SpeakerSegment>? speakers) => TranscriptionProgress(partialText: text, speakerSegments: speakers, progress: 1.0, isComplete: true, statusMessage: 'Perfeito!');
}

class AIService {
  static bool _initialized = false;
  static bool _processing = false;
  static String? _modelPath;
  static String? _llamaModelPath;

  static final _transcriptionController = StreamController<TranscriptionProgress>.broadcast();
  static Stream<TranscriptionProgress> get transcriptionStream => _transcriptionController.stream;

  static const String whisperFilename = 'whisper-base.bin';
  static const String llamaFilename = 'tinyllama-1.1b-chat-v1.0.Q4_K_M.gguf';

  static void _log(String message) {
    debugPrint('AI_LOG: $message');
  }

  static void _emitProgress(TranscriptionProgress progress) {
    _transcriptionController.add(progress);
  }

  static Future<void> initializeInBackground() async {
    if (_initialized) return;
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final whisperPath = '${appDir.path}/models/$whisperFilename';
      final llamaPath = '${appDir.path}/models/$llamaFilename';

      if (File(whisperPath).existsSync() && File(whisperPath).lengthSync() > 100 * 1024 * 1024) {
        _modelPath = whisperPath;
        _llamaModelPath = llamaPath;
        _initialized = true;
        AIManager.setState(AIState.readyWhisper, message: 'Pronto');
        return;
      }
      await checkAssetsIntegrity();
    } catch (e) {
      _log('Boot error: $e');
    }
  }

  static Future<bool> checkAssetsIntegrity() async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final modelDir = Directory('${appDir.path}/models');
      if (!await modelDir.exists()) await modelDir.create(recursive: true);

      final whisperPath = '${modelDir.path}/$whisperFilename';
      final llamaPath = '${modelDir.path}/$llamaFilename';

      await _copyModel(whisperFilename, whisperPath);
      await _copyModel(llamaFilename, llamaPath);

      _modelPath = whisperPath;
      _llamaModelPath = llamaPath;
      _initialized = true;
      AIManager.setState(AIState.readyWhisper, message: 'Pronto');
      return true;
    } catch (e) {
      return false;
    }
  }

  static Future<void> _copyModel(String assetName, String destPath) async {
    try {
      final data = await rootBundle.load('assets/models/$assetName');
      final file = File(destPath);
      final sink = file.openWrite();
      final totalBytes = data.lengthInBytes;
      const int chunkSize = 1024 * 1024;
      for (int i = 0; i < totalBytes; i += chunkSize) {
        final end = (i + chunkSize < totalBytes) ? i + chunkSize : totalBytes;
        sink.add(data.buffer.asUint8List(data.offsetInBytes + i, end - i));
        if (i % (chunkSize * 20) == 0) {
          AIManager.setState(AIState.loading, message: 'Configurando IA...', progress: i / totalBytes);
          await Future.delayed(const Duration(milliseconds: 5));
        }
      }
      await sink.flush();
      await sink.close();
    } catch (e) {
      rethrow;
    }
  }

  static Future<Transcription?> processAudio({
    required String audioPath,
    required String title,
    Function(double progress, String status)? onProgress,
  }) async {
    if (_processing) return null;
    _processing = true;

    try {
      _emitProgress(TranscriptionProgress.loading(0.1, 'Transcrevendo...'));
      if (!_initialized) await initializeInBackground();

      final appDir = await getApplicationDocumentsDirectory();
      final whisperPath = '${appDir.path}/models/$whisperFilename';

      // 1. Transcrever
      Transcription result = await _processWhisperNative(
        audioPath: audioPath,
        title: title,
        modelPath: whisperPath,
      );

      // 2. Limpeza Radical do texto
      String text = result.text.trim();

      final isSpanish = text.toLowerCase().contains('hola') || text.toLowerCase().contains(' soy ');
      if (isSpanish && text.isNotEmpty) {
        _log('⚠️ Detectada alucinação de espanhol. Traduzindo em silêncio...');
        final translated = await translateToPortuguese(text);
        if (translated != null && translated.isNotEmpty) {
          text = _extractAssistantContent(translated);
        }
      } else {
        text = _emergencyTermFix(text);
      }

      final segments = _smartDiarize(text);

      _emitProgress(TranscriptionProgress.complete(text, segments));
      _processing = false;

      return Transcription(
        id: result.id, title: result.title, audioPath: result.audioPath,
        text: text, wordTimestamps: result.wordTimestamps,
        createdAt: result.createdAt, duration: result.duration,
        isEncrypted: result.isEncrypted, speakerSegments: segments,
        summary: result.summary, actionItems: result.actionItems,
      );
    } catch (e) {
      _processing = false;
      return null;
    }
  }

  /// CRITICAL PARSER: Isola o conteúdo real ignorando instruções técnicas
  static String _extractAssistantContent(String input) {
    if (input.contains('<|assistant|>')) {
      input = input.split('<|assistant|>').last;
    }

    String clean = input.replaceAll(RegExp(r'<\|.*?\|>', dotAll: true), '');
    // Remove frases de comando que a IA às vezes repete por erro
    clean = clean.replaceAll(RegExp(r'^(Você é|Traduza|Resuma|Responda).*?[:\.]', multiLine: true, caseSensitive: false), '');
    clean = clean.replaceAll('Transcrição:', '').replaceAll('Tradução:', '');

    return clean.trim();
  }

  static String _sanitizeAIFeedback(String input) {
    String content = _extractAssistantContent(input);
    content = content.replaceAll('Resumo:', '').trim();
    return content;
  }

  static String _emergencyTermFix(String input) {
    // Regex de segurança: corrige qualquer palavra terminada em 'ou' -> 'o'
    // Ex: testandou -> testando, transcriçãou -> transcrição
    var fixed = input.replaceAll(RegExp(r'([a-zA-Záéíóúãõ])ou\b'), r'$1o');
    return fixed
        .replaceAll('Hola', 'Olá').replaceAll('hola', 'olá')
        .replaceAll('soy', 'sou').replaceAll('Soy', 'Sou')
        .replaceAll('estoy', 'estou').replaceAll('Estoy', 'Estou')
        .replaceAll('grabación', 'gravação').replaceAll('esta', 'esta')
        .replaceAll(' y ', ' e ').replaceAll('con ', 'com ');
  }

  static List<SpeakerSegment> _smartDiarize(String text) {
    if (text.isEmpty) return [];
    final paragraphs = text.split(RegExp(r'\n\n|\r\n\r\n'));
    final List<SpeakerSegment> segments = [];
    int speaker = 1;
    for (int i = 0; i < paragraphs.length; i++) {
      final p = paragraphs[i].trim();
      if (p.isEmpty) continue;
      if (i > 0) speaker = (speaker == 1) ? 2 : 1;
      segments.add(SpeakerSegment(
          speakerId: 'Voz $speaker',
          startTime: Duration(seconds: i * 5),
          endTime: Duration(seconds: (i + 1) * 5),
          text: p
      ));
    }
    return segments;
  }

  static Future<Transcription> _processWhisperNative({
    required String audioPath,
    required String title,
    required String modelPath,
  }) async {
    try {
      await WhisperPlatformService.initialize(modelPath);
      String? text = await WhisperPlatformService.transcribe(audioPath, language: 'pt');
      await WhisperPlatformService.release();
      if (text == null || text.isEmpty) return _generateFallback(audioPath, title);

      return Transcription(
        id: title.hashCode.abs().toString(),
        title: title, audioPath: audioPath, text: text,
        wordTimestamps: const [], createdAt: DateTime.now(),
        duration: const Duration(minutes: 1), isEncrypted: true,
        speakerSegments: [], summary: '', actionItems: const [],
      );
    } finally {
      try { WhisperBindings.dispose(); } catch (_) {}
    }
  }

  static Future<String?> translateToPortuguese(String text) async {
    final appDir = await getApplicationDocumentsDirectory();
    final llamaPath = '${appDir.path}/models/$llamaFilename';
    final rootToken = ServicesBinding.rootIsolateToken!;
    try {
      return await Isolate.run(() async {
        BackgroundIsolateBinaryMessenger.ensureInitialized(rootToken);
        if (!LlamaBindings.load()) return null;
        final ctx = LlamaBindings.initFromFile(llamaPath);
        if (ctx == null) return null;

        final prompt = '<|system|>\nVocê é um tradutor brasileiro. Traduza o áudio abaixo para Português do Brasil.\n<|user|>\n$text\n<|assistant|>\n';

        final res = LlamaBindings.generate(ctx: ctx, prompt: prompt);
        LlamaBindings.dispose();
        if (res == null) return null;
        return (res['response'] ?? res['summary'] ?? '').toString();
      });
    } catch (e) { return null; }
  }

  static Transcription _generateFallback(String audioPath, String title) {
    return Transcription(
      id: title.hashCode.abs().toString(), title: title, audioPath: audioPath,
      text: "Erro no motor local", wordTimestamps: const [], createdAt: DateTime.now(),
      duration: const Duration(minutes: 1), isEncrypted: true,
      speakerSegments: [], summary: '', actionItems: const [],
    );
  }

  static Future<Transcription?> generateSummary({required String transcriptionId, required String text}) async {
    final appDir = await getApplicationDocumentsDirectory();
    final llamaPath = '${appDir.path}/models/$llamaFilename';
    final rootToken = ServicesBinding.rootIsolateToken!;
    try {
      return await Isolate.run(() async {
        BackgroundIsolateBinaryMessenger.ensureInitialized(rootToken);
        if (!LlamaBindings.load()) return null;
        final ctx = LlamaBindings.initFromFile(llamaPath);
        if (ctx == null) return null;
        final prompt = '<|system|>\nResuma em Português Brasileiro oficial.\n<|user|>\n$text\n<|assistant|>\n';
        final res = LlamaBindings.generate(ctx: ctx, prompt: prompt);
        LlamaBindings.dispose();
        if (res == null) return null;
        String rawResult = (res['summary'] ?? res['response'] ?? '').toString();
        String summaryText = _extractAssistantContent(rawResult);

        return Transcription(
          id: transcriptionId, title: '', audioPath: '', text: text,
          wordTimestamps: const [], createdAt: DateTime.now(),
          duration: const Duration(minutes: 1), isEncrypted: true,
          speakerSegments: const [], summary: summaryText.isEmpty ? "Resumo não disponível." : summaryText,
          actionItems: res['actionItems'] != null ? List<String>.from(res['actionItems']) : [],
        );
      });
    } catch (e) { return null; }
  }

  static Future<String?> generateChatResponse({required String transcriptionId, required String context, String? query}) async {
    final appDir = await getApplicationDocumentsDirectory();
    final llamaPath = '${appDir.path}/models/$llamaFilename';
    final rootToken = ServicesBinding.rootIsolateToken!;
    final userQuestion = query ?? "Resuma o que foi dito.";

    try {
      return await Isolate.run(() async {
        BackgroundIsolateBinaryMessenger.ensureInitialized(rootToken);
        if (!LlamaBindings.load()) return null;
        final ctx = LlamaBindings.initFromFile(llamaPath);
        if (ctx == null) return null;
        final prompt = '<|system|>\nVocê é o assistente inteligente PrivaChat. Use a transcrição para responder em Português Brasileiro. Não repita a transcrição.\n<|user|>\nTranscrição: $context\nPergunta: $userQuestion\n<|assistant|>\n';
        final res = LlamaBindings.generate(ctx: ctx, prompt: prompt);
        LlamaBindings.dispose();
        if (res == null) return null;
        return _extractAssistantContent((res['response'] ?? '').toString());
      });
    } catch (e) { return null; }
  }
}