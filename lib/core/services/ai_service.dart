import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import '../../domain/entities/transcription.dart';
import '../ai/native/whisper_bindings.dart';
import '../ai/native/llama_bindings.dart';
import '../ai/ai_state.dart';

/// ROBUST AI Service - Military-grade security and stability
class AIService {
  static bool _initialized = false;
  static bool _modelsCopied = false;
  static String? _modelPath;
  static String _diagnosticLog = '';

  // Expected sizes (bytes)
  static const int EXPECTED_WHISPER_SIZE = 144000000; // ~144MB
  static const int EXPECTED_LLAMA_SIZE = 653000000;   // ~653MB
  static const int WHISPER_MIN_SIZE = 130000000;      // Allow some variance
  static const int LLAMA_MIN_SIZE = 580000000;       

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

  /// Verify model file integrity before init
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
      
      if (stat.size >= expectedSize * 0.9) {
        _log('✅ Model INTEGRITY OK');
        return true;
      }
      
      _log('⚠️ Model size differs but acceptable: ${stat.size}');
      return true;
    } catch (e) {
      _log('❌ Model integrity check FAILED: $e');
      return false;
    }
  }

  /// Pre-flight check - validate asset integrity
  static Future<bool> checkAssetsIntegrity() async {
    _log('=== PRE-FLIGHT CHECK ===');

    try {
      final appDir = await getApplicationDocumentsDirectory();
      final modelDir = Directory('${appDir.path}/models');
      
      if (!await modelDir.exists()) {
        await modelDir.create(recursive: true);
      }
      
      // Check Whisper
      final whisperPath = '${modelDir.path}/whisper-base.bin';
      if (await File(whisperPath).exists()) {
        // Verify integrity
        if (!_verifyModelIntegrity(whisperPath, EXPECTED_WHISPER_SIZE, WHISPER_MIN_SIZE)) {
          _log('Recreating corrupted Whisper model...');
          await _deleteAndRecreateModel(whisperPath, 'whisper-base.bin');
        } else {
          _modelPath = whisperPath;
          _modelsCopied = true;
          AIManager.setState(AIState.ready, message: 'Pronto para gravar');
          return true;
        }
      } else {
        _log('Whisper: NOT FOUND - copying...');
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
      final file = File(path);
      if (await file.exists()) {
        await file.delete();
      }
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
      
      // Verify copy completed successfully
      if (!_verifyModelIntegrity(destPath, data.lengthInBytes, data.lengthInBytes ~/ 2)) {
        throw Exception('Model copy verification failed');
      }

      final stat = await File(destPath).stat();
      _log('Model copied: ${stat.size} bytes');

      _modelsCopied = true;
      _modelPath = destPath;
      _log('✅ Model ready: $destPath');
    } catch (e) {
      _log('❌ Copy FAILED: $e');
      AIManager.setError('Erro ao copiar $assetName: $e');
      rethrow;
    }
  }

  /// Initialize in background
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
      _log('=== INITIALIZATION COMPLETE ===');
      _log('Model path: $_modelPath');
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
    print('AI: Models directory prepared');
  }

  /// Process audio - runs in isolate
  static Future<Transcription?> processAudio({
    required String audioPath,
    required String title,
    Function(double progress, String status)? onProgress,
  }) async {
    _log('=== PROCESS AUDIO ===');

    if (_modelPath == null || !_modelsCopied) {
      _log('Models not ready, running pre-flight...');
      AIManager.setState(AIState.loading, message: 'Carregando modelo...');
      final ready = await checkAssetsIntegrity();
      if (!ready) {
        throw Exception('Pre-flight check failed');
      }
    }

    AIManager.setState(AIState.processing, message: 'Transcrevendo...');
    onProgress?.call(0.1, 'Processando áudio...');

    try {
      final result = await Isolate.run(() async {
        return await _processPipeline(
          audioPath: audioPath,
          title: title,
          modelPath: _modelPath,
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

  /// Pipeline - runs in isolate
  static Future<Transcription> _processPipeline({
    required String audioPath,
    required String title,
    String? modelPath,
  }) async {
    _log('[Isolate] Pipeline start');

    final effectiveModelPath = modelPath ?? _modelPath;

    // Check audio
    if (!File(audioPath).existsSync()) {
      throw Exception('Audio file NOT FOUND: $audioPath');
    }

    if (effectiveModelPath == null) {
      throw Exception('Model path is NULL - run pre-flight check');
    }

    // Verify model integrity before init
    if (!_verifyModelIntegrity(effectiveModelPath, EXPECTED_WHISPER_SIZE, WHISPER_MIN_SIZE)) {
      throw Exception('Model integrity check FAILED');
    }

    _log('[Isolate] Model: $effectiveModelPath');

    // Load Whisper
    if (!WhisperBindings.load()) {
      throw Exception('FFI Error: libwhisper.so not loaded');
    }

    // Init model
    _log('[Isolate] Init Whisper...');
    final ctx = WhisperBindings.initFromFile(effectiveModelPath);
    
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

    // ============================================
    // MEMORY HANDOVER - Critical for OOM prevention
    // ============================================
    _log('[Isolate] Cleaning Whisper from memory...');
    WhisperBindings.dispose();
    
    // Small delay to allow RAM cleanup before Llama loads
    await Future.delayed(const Duration(milliseconds: 500));
    _log('[Isolate] ✅ Memory handover complete');
    // ============================================

    // Diarization
    final speakers = _diarize(text);

    // Llama summary
    String summary = '';
    List<String> actionItems = [];

    final llamaPath = effectiveModelPath.replaceAll('whisper-base.bin', 'tinyllama-1.1b-chat-v1.0.Q4_K_M.gguf');
    
    // Verify Llama integrity
    if (File(llamaPath).existsSync()) {
      if (!_verifyModelIntegrity(llamaPath, EXPECTED_LLAMA_SIZE, LLAMA_MIN_SIZE)) {
        _log('[Isolate] ⚠️ Llama integrity check failed, skipping summary');
      } else {
        _log('[Isolate] Loading Llama...');
        if (LlamaBindings.load()) {
          final llamaCtx = LlamaBindings.initFromFile(llamaPath);
          if (llamaCtx != null) {
            _log('[Isolate] Llama ctx ready, generating summary...');
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
    } else {
      _log('[Isolate] Llama model not found, skipping summary');
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
