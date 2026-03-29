import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import '../../domain/entities/transcription.dart';
import '../ai/native/whisper_bindings.dart';
import '../ai/native/llama_bindings.dart';
import '../ai/ai_state.dart';

/// ROBUST AI Service - Pre-flight check, state machine, diagnostics, auto-cleanup
class AIService {
  static bool _initialized = false;
  static bool _modelsCopied = false;
  static String? _modelPath;
  static String _diagnosticLog = '';

  // Expected sizes (bytes)
  static const int EXPECTED_WHISPER_SIZE = 144000000; // ~144MB
  static const int EXPECTED_LLAMA_SIZE = 653000000;   // ~653MB

  static bool get isModelsReady => _modelsCopied;
  static String? get modelPath => _modelPath;
  static String get diagnosticLog => _diagnosticLog;

  /// Add diagnostic entry
  static void _log(String message) {
    final timestamp = DateTime.now().toIso8601String();
    final entry = '[$timestamp] $message';
    _diagnosticLog += '$entry\n';
    print('AI: $message');
  }

  /// Pre-flight check - validate asset integrity
  static Future<bool> checkAssetsIntegrity() async {
    _log('=== PRE-FLIGHT CHECK ===');

    try {
      final appDir = await getApplicationDocumentsDirectory();
      final modelDir = Directory('${appDir.path}/models');
      
      // Check Whisper
      final whisperPath = '${modelDir.path}/whisper-base.bin';
      if (await File(whisperPath).exists()) {
        final stat = await File(whisperPath).stat();
        _log('Whisper exists: ${stat.size} bytes');
        
        if (stat.size >= EXPECTED_WHISPER_SIZE * 0.9) { // Allow 10% variance
          _log('Whisper: VALID (${stat.size} bytes)');
          _modelPath = whisperPath;
          _modelsCopied = true;
          AIManager.setState(AIState.ready, message: 'Pronto para gravar');
          return true;
        } else {
          _log('Whisper: INVALID SIZE (${stat.size} < $EXPECTED_WHISPER_SIZE)');
          _log('Recreating Whisper model...');
          await _deleteAndRecreateModel(whisperPath, 'whisper-base.bin');
        }
      } else {
        _log('Whisper: NOT FOUND');
        await _copyModel('whisper-base.bin', whisperPath);
      }

      AIManager.setState(AIState.ready, message: 'Pronto para gravar');
      return true;
    } catch (e) {
      _log('Pre-flight FAILED: $e');
      AIManager.setError('Falha na verificação: $e');
      return false;
    }
  }

  /// Delete and recreate model
  static Future<void> _deleteAndRecreateModel(String path, String assetName) async {
    try {
      _log('Deleting corrupted model: $path');
      await File(path).delete();
    } catch (e) {
      _log('Delete error: $e');
    }
    await _copyModel(assetName, path);
  }

  /// Copy model from assets with verification
  static Future<void> _copyModel(String assetName, String destPath) async {
    _log('Copying $assetName...');
    AIManager.setState(AIState.loading, message: 'Baixando $assetName...');

    try {
      final data = await rootBundle.load('assets/models/$assetName');
      _log('Asset loaded: ${data.lengthInBytes} bytes');

      await File(destPath).writeAsBytes(data.buffer.asUint8List());
      
      final stat = await File(destPath).stat();
      _log('Model copied: ${stat.size} bytes');

      if (stat.size < 1000000) {
        throw Exception('Model too small: ${stat.size} bytes');
      }

      _modelsCopied = true;
      _modelPath = destPath;
      _log('✅ Model ready: $destPath');
    } catch (e) {
      _log('❌ Copy FAILED: $e');
      AIManager.setError('Erro ao copiar $assetName: $e');
      rethrow;
    }
  }

  /// Initialize in background - UI stays responsive
  static Future<void> initializeInBackground() async {
    if (_initialized) return;

    _log('=== INITIALIZATION START ===');
    AIManager.setState(AIState.loading, message: 'Preparando IA...');

    try {
      // Run in isolate
      await Isolate.run(() async {
        await _copyModelsToDocuments();
      });

      // Pre-flight check
      final ready = await checkAssetsIntegrity();
      if (!ready) {
        _log('Post-initialization check failed');
      }

      _initialized = true;
      _log('=== INITIALIZATION COMPLETE ===');
    } catch (e) {
      _log('❌ INITIALIZATION FAILED: $e');
      AIManager.setError('Inicialização falhou: $e');
    }
  }

  /// Copy models to documents
  static Future<void> _copyModelsToDocuments() async {
    final appDir = await getApplicationDocumentsDirectory();
    final modelDir = Directory('${appDir.path}/models');

    if (!await modelDir.exists()) {
      await modelDir.create(recursive: true);
    }

    // Whisper
    final whisperAsset = 'assets/models/whisper-base.bin';
    final whisperDest = '${modelDir.path}/whisper-base.bin';

    if (!await File(whisperDest).exists()) {
      await _copyModel('whisper-base.bin', whisperDest);
    }

    // Llama
    final llamaDest = '${modelDir.path}/tinyllama-1.1b-chat-v1.0.Q4_K_M.gguf';
    if (!await File(llamaDest).exists()) {
      await _copyModel('tinyllama-1.1b-chat-v1.0.Q4_K_M.gguf', llamaDest);
    }

    _modelsCopied = true;
    _log('All models copied');
  }

  /// Process audio - runs in isolate
  static Future<Transcription?> processAudio({
    required String audioPath,
    required String title,
    Function(double progress, String status)? onProgress,
  }) async {
    _log('=== PROCESS AUDIO ===');

    if (!AIManager.isReady && !_modelsCopied) {
      _log('Models not ready, running pre-flight...');
      await checkAssetsIntegrity();
    }

    AIManager.setState(AIState.processing, message: 'Transcrevendo...');
    onProgress?.call(0.1, 'Processando áudio...');

    try {
      final result = await Isolate.run(() async {
        return await _processPipeline(audioPath: audioPath, title: title);
      });

      AIManager.setState(AIState.ready, message: 'Pronto');
      onProgress?.call(1.0, 'Completo');
      _log('=== PROCESS COMPLETE ===');

      return result;
    } catch (e) {
      _log('❌ PROCESS FAILED: $e');
      AIManager.setError('Processamento falhou: $e');
      rethrow;
    }
  }

  /// Pipeline - runs in isolate
  static Future<Transcription> _processPipeline({
    required String audioPath,
    required String title,
  }) async {
    _log('[Isolate] Pipeline start');

    // Check audio
    if (!File(audioPath).existsSync()) {
      throw Exception('Audio file NOT FOUND: $audioPath');
    }

    if (_modelPath == null) {
      throw Exception('Model path is NULL - run pre-flight check');
    }

    _log('[Isolate] Model: $_modelPath');

    // Load Whisper
    if (!WhisperBindings.load()) {
      throw Exception('FFI Error: libwhisper.so not loaded');
    }

    // Init model
    _log('[Isolate] Init Whisper...');
    final ctx = WhisperBindings.initFromFile(_modelPath!);
    
    if (ctx == null) {
      throw Exception('FFI Error: whisper_init_from_file returned NULL');
    }

    _log('[Isolate] ctx = ${ctx.address}');

    // Transcribe
    _log('[Isolate] Transcribing...');
    final text = WhisperBindings.full(ctx: ctx, audioPath: audioPath);
    
    if (text == null || text.isEmpty) {
      WhisperBindings.dispose();
      throw Exception('FFI Error: whisper returned empty');
    }

    _log('[Isolate] Text: $text');

    // Auto-cleanup
    WhisperBindings.dispose();
    _log('[Isolate] Whisper disposed');

    // Diarization
    final speakers = _diarize(text);

    // Llama summary
    String summary = '';
    List<String> actionItems = [];

    final llamaPath = _modelPath!.replaceAll('whisper-base.bin', 'tinyllama-1.1b-chat-v1.0.Q4_K_M.gguf');
    
    if (File(llamaPath).existsSync()) {
      _log('[Isolate] Llama processing...');
      if (LlamaBindings.load()) {
        final llamaCtx = LlamaBindings.initFromFile(llamaPath);
        if (llamaCtx != null) {
          final result = LlamaBindings.generate(ctx: llamaCtx, prompt: text);
          if (result != null) {
            summary = result['summary'] ?? '';
            actionItems = List<String>.from(result['actionItems'] ?? []);
          }
        }
        LlamaBindings.dispose();
        _log('[Isolate] Llama disposed');
      }
    }

    _log('[Isolate] Pipeline complete');

    return Transcription(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: title,
      audioPath: audioPath,
      text: text,
      wordTimestamps: [],
      createdAt: DateTime.now(),
      duration: const Duration(minutes: 2),
      isEncrypted: false,
      speakerSegments: speakers,
      summary: summary,
      actionItems: actionItems,
    );
  }

  static List<SpeakerSegment> _diarize(String text) {
    if (text.isEmpty) return [];
    final lines = text.split('\n').where((l) => l.trim().isNotEmpty).toList();
    final speakers = <SpeakerSegment>[];
    var time = 0;
    for (var line in lines) {
      speakers.add(SpeakerSegment(
        speakerId: 'speaker_${speakers.length + 1}',
        startTime: Duration(seconds: time),
        endTime: Duration(seconds: time + 5),
        text: line.trim(),
      ));
      time += 5;
    }
    return speakers;
  }

  /// Get diagnostic log for support
  static String getDiagnostics() {
    return '''
=== PrivaVoice AI Diagnostics ===
Time: ${DateTime.now().toIso8601String()}
State: ${AIManager.state}
Model Path: $_modelPath
Models Copied: $_modelsCopied
Initialized: $_initialized
Error: ${AIManager.lastError}

--- Diagnostic Log ---
$_diagnosticLog
''';
  }
}
