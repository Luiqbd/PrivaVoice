import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import '../../domain/entities/transcription.dart';
import '../ai/native/whisper_bindings.dart';
import '../ai/native/llama_bindings.dart';
import '../ai/ai_state.dart';

/// ROBUST AI Service - Military-grade stability
class AIService {
  static bool _initialized = false;
  static bool _modelsCopied = false;
  static String? _modelPath;
  static String _diagnosticLog = '';

  // Expected sizes - exact model filenames
  static const int EXPECTED_WHISPER_SIZE = 144000000;
  static const int EXPECTED_LLAMA_SIZE = 653000000;
  static const int WHISPER_MIN_SIZE = 130000000;
  static const int LLAMA_MIN_SIZE = 580000000;

  // Exact filenames - no typos!
  static const String WHISPER_FILENAME = 'whisper-base.bin';
  static const String LLAMA_FILENAME = 'tinyllama-1.1b-chat-v1.0.Q4_K_M.gguf';

  static bool get isModelsReady => _modelsCopied;
  static String? get modelPath => _modelPath;
  static String get diagnosticLog => _diagnosticLog;

  static void _log(String message) {
    final timestamp = DateTime.now().toIso8601String();
    final entry = '[$timestamp] $message';
    _diagnosticLog += '$entry\n';
    print('AI: $message');
  }

  /// Validate model path exists - critical for persistence
  static String? _validateModelPath() {
    if (_modelPath == null) {
      _log('❌ _modelPath is NULL');
      return null;
    }
    
    final file = File(_modelPath!);
    if (!file.existsSync()) {
      _log('❌ Model file NOT FOUND at: $_modelPath');
      _modelPath = null;
      _modelsCopied = false;
      return null;
    }
    
    final stat = file.statSync();
    _log('✅ Model path validated: $_modelPath (${stat.size} bytes)');
    return _modelPath;
  }

  /// Verify model integrity before init
  static bool _verifyModelIntegrity(String path, int expectedSize, int minSize) {
    try {
      final file = File(path);
      if (!file.existsSync()) {
        _log('Model NOT FOUND: $path');
        return false;
      }
      
      final stat = file.statSync();
      _log('Model size: ${stat.size} bytes (expected: $expectedSize)');
      
      if (stat.size < minSize) {
        _log('❌ Model INCOMPLETE: ${stat.size} < $minSize');
        return false;
      }
      
      _log('✅ Model INTEGRITY OK');
      return true;
    } catch (e) {
      _log('❌ Model integrity check FAILED: $e');
      return false;
    }
  }

  /// Pre-flight check
  static Future<bool> checkAssetsIntegrity() async {
    _log('=== PRE-FLIGHT CHECK ===');

    try {
      final appDir = await getApplicationDocumentsDirectory();
      final modelDir = Directory('${appDir.path}/models');
      
      if (!await modelDir.exists()) {
        await modelDir.create(recursive: true);
      }
      
      // Use exact filename
      final whisperPath = '${modelDir.path}/$WHISPER_FILENAME';
      _log('Looking for Whisper at: $whisperPath');
      
      // Check if already exists and is valid
      if (await File(whisperPath).exists()) {
        if (!_verifyModelIntegrity(whisperPath, EXPECTED_WHISPER_SIZE, WHISPER_MIN_SIZE)) {
          _log('Recreating corrupted Whisper model...');
          await _deleteAndRecreateModel(whisperPath, WHISPER_FILENAME);
        } else {
          _modelPath = whisperPath;
          _modelsCopied = true;
          AIManager.setState(AIState.ready, message: 'Pronto para gravar');
          return true;
        }
      } else {
        _log('Whisper: NOT FOUND - copying...');
        await _copyModel(WHISPER_FILENAME, whisperPath);
      }

      // Final validation
      _validateModelPath();
      AIManager.setState(AIState.ready, message: 'Pronto para gravar');
      return true;
    } catch (e) {
      _log('Pre-flight FAILED: $e');
      AIManager.setError('Falha na verificação: $e');
      return false;
    }
  }

  static Future<void> _deleteAndRecreateModel(String path, String assetName) async {
    try {
      _log('Deleting corrupted model: $path');
      final file = File(path);
      if (await file.exists()) {
        await file.delete();
      }
    } catch (e) {
      _log('Delete error: $e');
    }
    await _copyModel(assetName, path);
  }

  /// Copy model with proper flush and delay
  static Future<void> _copyModel(String assetName, String destPath) async {
    _log('Copying $assetName...');
    AIManager.setState(AIState.loading, message: 'Baixando $assetName...');

    try {
      // Load from assets
      final data = await rootBundle.load('assets/models/$assetName');
      _log('Asset loaded: ${data.lengthInBytes} bytes');

      // Write to file
      final file = File(destPath);
      final sink = file.openWrite();
      sink.add(data.buffer.asUint8List());
      
      // CRITICAL: Flush and close sink before proceeding
      await sink.flush();
      await sink.close();
      
      _log('Sink closed, waiting for filesystem...');
      
      // CRITICAL: Give Android filesystem time to process 144MB
      await Future.delayed(const Duration(milliseconds: 500));
      
      // Verify copy completed successfully
      if (!file.existsSync()) {
        throw Exception('File not found after write');
      }
      
      final stat = file.statSync();
      _log('Model copied: ${stat.size} bytes');
      
      if (stat.size < data.lengthInBytes ~/ 2) {
        throw Exception('Model copy incomplete: ${stat.size} < ${data.lengthInBytes ~/ 2}');
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

  /// Initialize in background - call AFTER permissions granted
  static Future<void> initializeInBackground() async {
    if (_initialized) return;

    _log('=== INITIALIZATION START ===');
    AIManager.setState(AIState.loading, message: 'Preparando IA...');

    try {
      // Copy models in isolate
      await Isolate.run(() async {
        await _copyModelsToDocuments();
      });

      // Pre-flight check in main isolate
      final ready = await checkAssetsIntegrity();
      if (!ready) {
        _log('Post-initialization check failed');
      }

      _initialized = true;
      _validateModelPath();  // Final validation
      _log('=== INITIALIZATION COMPLETE ===');
      _log('Final model path: $_modelPath');
    } catch (e) {
      _log('❌ INITIALIZATION FAILED: $e');
      AIManager.setError('Inicialização falhou: $e');
    }
  }

  static Future<void> _copyModelsToDocuments() async {
    final appDir = await getApplicationDocumentsDirectory();
    final modelDir = Directory('${appDir.path}/models');

    if (!await modelDir.exists()) {
      await modelDir.create(recursive: true);
    }
    print('AI: Models directory prepared');
  }

  /// Process audio
  static Future<Transcription?> processAudio({
    required String audioPath,
    required String title,
    Function(double progress, String status)? onProgress,
  }) async {
    _log('=== PROCESS AUDIO ===');

    // CRITICAL: Validate path before processing
    final validatedPath = _validateModelPath();
    if (validatedPath == null) {
      _log('Models not ready, running pre-flight...');
      AIManager.setState(AIState.loading, message: 'Carregando modelo...');
      final ready = await checkAssetsIntegrity();
      if (!ready) {
        throw Exception('Pre-flight check failed');
      }
      _validateModelPath();  // Re-validate after pre-flight
    }

    // Verify audio file
    _log('Checking audio file: $audioPath');
    final audioFile = File(audioPath);
    if (!audioFile.existsSync()) {
      throw Exception('Audio file NOT FOUND: $audioPath');
    }
    
    final audioStat = audioFile.statSync();
    _log('Audio file size: ${audioStat.size} bytes');
    
    if (audioStat.size < 10000) {  // < 10KB
      _log('⚠️ WARNING: Audio file too small (${audioStat.size} bytes). May be empty!');
      AIManager.setError('Áudio vazio ou corrompido');
      throw Exception('Audio file too small (${audioStat.size} bytes). Need at least 10KB.');
    }

    AIManager.setState(AIState.processing, message: 'Transcrevendo...');
    onProgress?.call(0.1, 'Processando áudio...');

    try {
      // Validate path one more time before isolate
      final safePath = _validateModelPath();
      if (safePath == null) {
        throw Exception('Model path lost between validation and isolate');
      }

      final result = await Isolate.run(() async {
        return await _processPipeline(
          audioPath: audioPath,
          title: title,
          modelPath: safePath,
        );
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

  /// Pipeline with finally block for memory cleanup
  static Future<Transcription> _processPipeline({
    required String audioPath,
    required String title,
    required String modelPath,
  }) async {
    _log('[Isolate] Pipeline start');
    _log('[Isolate] Using model path: $modelPath');

    Pointer<Void>? whisperCtx;
    Pointer<Void>? llamaCtx;

    try {
      // Check audio
      if (!File(audioPath).existsSync()) {
        throw Exception('Audio file NOT FOUND: $audioPath');
      }

      final audioStat = File(audioPath).statSync();
      _log('[Isolate] Audio size: ${audioStat.size} bytes');

      // Verify model integrity
      if (!_verifyModelIntegrity(modelPath, EXPECTED_WHISPER_SIZE, WHISPER_MIN_SIZE)) {
        throw Exception('Model integrity check FAILED');
      }

      _log('[Isolate] Model: $modelPath');

      // Load Whisper
      if (!WhisperBindings.load()) {
        throw Exception('FFI Error: libwhisper.so not loaded');
      }

      // Init model
      _log('[Isolate] Init Whisper...');
      whisperCtx = WhisperBindings.initFromFile(modelPath);
      
      if (whisperCtx == null) {
        throw Exception('FFI Error: whisper_init_from_file returned NULL');
      }

      _log('[Isolate] ctx = ${whisperCtx.address}');

      // Transcribe
      _log('[Isolate] Transcribing...');
      final text = WhisperBindings.full(ctx: whisperCtx, audioPath: audioPath);
      
      if (text == null || text.isEmpty) {
        throw Exception('FFI Error: whisper returned empty');
      }

      _log('[Isolate] Text: $text');

      // Diarization
      final speakers = _diarize(text);

      // Llama summary - use EXACT filename
      String summary = '';
      List<String> actionItems = [];

      final llamaPath = modelPath.replaceAll(WHISPER_FILENAME, LLAMA_FILENAME);
      _log('[Isolate] Llama path: $llamaPath');
      
      if (File(llamaPath).existsSync()) {
        if (_verifyModelIntegrity(llamaPath, EXPECTED_LLAMA_SIZE, LLAMA_MIN_SIZE)) {
          _log('[Isolate] Loading Llama...');
          if (LlamaBindings.load()) {
            llamaCtx = LlamaBindings.initFromFile(llamaPath);
            if (llamaCtx != null) {
              _log('[Isolate] Llama ctx ready, generating summary...');
              final result = LlamaBindings.generate(ctx: llamaCtx, prompt: text);
              if (result != null) {
                summary = result['summary'] ?? '';
                actionItems = List<String>.from(result['actionItems'] ?? []);
              }
            }
          }
        }
      } else {
        _log('[Isolate] Llama model NOT FOUND at: $llamaPath');
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
      
    } finally {
      // ============================================
      // MEMORY CLEANUP - Always runs, even on error
      // ============================================
      _log('[Isolate] Finally block: Cleaning up memory...');
      
      if (whisperCtx != null) {
        try {
          WhisperBindings.dispose();
          _log('[Isolate] Whisper disposed');
        } catch (e) {
          _log('[Isolate] Whisper dispose error: $e');
        }
      }
      
      if (llamaCtx != null) {
        try {
          LlamaBindings.dispose();
          _log('[Isolate] Llama disposed');
        } catch (e) {
          _log('[Isolate] Llama dispose error: $e');
        }
      }
      
      // Small delay for RAM cleanup
      await Future.delayed(const Duration(milliseconds: 500));
      _log('[Isolate] ✅ Memory cleanup complete');
      // ============================================
    }
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
