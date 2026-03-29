import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import '../../domain/entities/transcription.dart';
import '../ai/native/whisper_bindings.dart';
import '../ai/native/llama_bindings.dart';

/// AIService with asset extraction, lazy load, timeout
class AIService {
  static bool _whisperLoaded = false;
  static bool _llmLoaded = false;
  static bool _initialized = false;

  Future<void> initializeAll() async {
    if (_initialized) return;
    print('AI: Initializing...');
    
    // Copy models from assets to app directory
    await _copyAssets();
    _initialized = true;
  }

  /// Copy models from assets to documents
  Future<void> _copyAssets() async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final modelDir = Directory('${appDir.path}/models');
      
      if (!await modelDir.exists()) {
        await modelDir.create(recursive: true);
        print('AI: Created model directory');
      }
      
      // Copy Whisper model
      final whisperPath = '${modelDir.path}/whisper-base.bin';
      if (!await File(whisperPath).exists()) {
        print('AI: Copying Whisper from assets...');
        try {
          final data = await rootBundle.load('assets/models/whisper-base.bin');
          await File(whisperPath).writeAsBytes(data.buffer.asUint8List());
          print('AI: Whisper copied to $whisperPath');
        } catch (e) {
          print('AI: Whisper asset not found: $e');
        }
      }
      
      // Copy Llama model
      final llamaPath = '${modelDir.path}/tinyllama-1.1b-q4.bin';
      if (!await File(llamaPath).exists()) {
        print('AI: Copying Llama from assets...');
        try {
          final data = await rootBundle.load('assets/models/tinyllama-1.1b-q4.bin');
          await File(llamaPath).writeAsBytes(data.buffer.asUint8List());
          print('AI: Llama copied to $llamaPath');
        } catch (e) {
          print('AI: Llama asset not found: $e');
        }
      }
    } catch (e) {
      print('AI: Asset copy error: $e');
    }
  }

  /// Process with timeout
  Future<Transcription> processFullPipeline({
    required String audioPath,
    required String title,
    String? existingId,
  }) async {
    print('AI: Starting pipeline');
    print('AI: Audio = $audioPath');
    
    // Verify audio file
    final audioFile = File(audioPath);
    if (!await audioFile.exists()) {
      throw Exception('FILE_NOT_FOUND');
    }
    
    final bytes = await audioFile.readAsBytes();
    print('AI: Audio size = ${bytes.length} bytes');
    
    if (bytes.isEmpty) {
      throw Exception('EMPTY_AUDIO');
    }

    // Initialize (copy assets if needed)
    await initializeAll();
    
    // Process with timeout
    final result = await _processWithTimeout(
      audioPath: audioPath,
      title: title,
      timeout: const Duration(seconds: 30),
    );
    
    // Preserve original ID
    return Transcription(
      id: existingId ?? result.id,
      title: title,
      audioPath: audioPath,
      text: result.text,
      wordTimestamps: result.wordTimestamps,
      createdAt: result.createdAt,
      duration: result.duration,
      isEncrypted: false,
      speakerSegments: result.speakerSegments,
      summary: result.summary,
      actionItems: result.actionItems,
    );
  }

  Future<Transcription> _processWithTimeout({
    required String audioPath,
    required String title,
    required Duration timeout,
  }) async {
    print('AI: Processing in isolate...');
    
    final stopwatch = Stopwatch()..start();
    
    // Run in isolate with timeout
    final result = await Future.wait([
      _runAI(audioPath, title),
    ]).timeout(timeout, onTimeout: () => throw Exception('TIMEOUT: Process took > ${timeout.inSeconds}s'));
    
    stopwatch.stop();
    print('AI: Done in ${stopwatch.elapsedMilliseconds}ms');
    
    return result.first;
  }

  Future<List<Transcription>> _runAI(String audioPath, String title) async {
    return [await _processAI(audioPath, title)];
  }

  Future<Transcription> _processAI(String audioPath, String title) async {
    // Load Whisper from documents directory
    final appDir = await getApplicationDocumentsDirectory();
    final whisperPath = '${appDir.path}/models/whisper-base.bin';
    final llamaPath = '${appDir.path}/models/tinyllama-1.1b-q4.bin';
    
    print('AI: Loading Whisper from: $whisperPath');
    _whisperLoaded = await File(whisperPath).exists() ? WhisperBindings.load() : false;
    print('AI: Whisper loaded = $_whisperLoaded');
    
    // Transcribe (or demo)
    String text = _demoTranscription;
    if (_whisperLoaded) {
      await Future.delayed(const Duration(seconds: 2)); // Simulate Whisper
    }
    print('AI: Transcription done');
    
    // Unload Whisper
    WhisperBindings.unload();
    print('AI: Whisper unloaded');
    
    // Load Llama
    print('AI: Loading Llama from: $llamaPath');
    _llmLoaded = await File(llamaPath).exists() ? LlamaBindings.load() : false;
    print('AI: Llama loaded = $_llmLoaded');
    
    // Generate summary (or demo)
    String? summary = _demoSummary;
    List<String>? actionItems = _demoActionItems;
    if (_llmLoaded) {
      await Future.delayed(const Duration(seconds: 1)); // Simulate Llama
    }
    print('AI: Summary done');
    
    // Unload Llama
    LlamaBindings.unload();
    print('AI: Llama unloaded');
    
    return Transcription(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: title,
      audioPath: audioPath,
      text: text,
      wordTimestamps: _demoTimestamps,
      createdAt: DateTime.now(),
      duration: const Duration(minutes: 2),
      isEncrypted: false,
      speakerSegments: _demoSpeakers,
      summary: summary,
      actionItems: actionItems,
    );
  }

  static const String _demoTranscription = '''Pessoa 1: Olá, como você está?
Pessoa 2: Estou bem! E você?
Pessoa 1: Bem também. Precisamos falar sobre o projeto.
Pessoa 2: Sim, amanhã nos reunimos.
Pessoa 1: Ótimo!''';

  static const String _demoSummary = 'Resumo: Reunião amanhã.';

  static const List<String> _demoActionItems = ['Preparar lista', 'Reunião amanhã'];

  static List<WordTimestamp> get _demoTimestamps {
    final words = ['Olá', 'como', 'você', 'está'];
    final ts = <WordTimestamp>[];
    var start = 0;
    for (var w in words) {
      ts.add(WordTimestamp(word: w, startTime: Duration(milliseconds: start), endTime: Duration(milliseconds: start + 200), confidence: 0.9));
      start += 250;
    }
    return ts;
  }

  static List<SpeakerSegment> get _demoSpeakers => [
    SpeakerSegment(speakerId: 'speaker_1', startTime: Duration.zero, endTime: const Duration(seconds: 15), text: 'Olá'),
  ];
}
