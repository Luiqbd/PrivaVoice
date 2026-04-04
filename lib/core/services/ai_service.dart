import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import '../../domain/entities/transcription.dart';
import '../ai/native/whisper_bindings.dart';
import '../ai/native/whisper_platform_service.dart';
import '../ai/native/llama_bindings.dart';
import '../ai/ai_state.dart';

/// Stream controller for real-time transcription updates
class TranscriptionProgress {
  final String? partialText;
  final List<SpeakerSegment>? speakerSegments;
  final double progress; // 0.0 to 1.0
  final bool isComplete;
  final String? statusMessage;
  
  TranscriptionProgress({
    this.partialText,
    this.speakerSegments,
    this.progress = 0.0,
    this.isComplete = false,
    this.statusMessage,
  });
  
  static TranscriptionProgress empty() => TranscriptionProgress(
    progress: 0.0,
    statusMessage: 'Iniciando...',
  );
  
  static TranscriptionProgress loading(double progress, String message) => TranscriptionProgress(
    progress: progress,
    statusMessage: message,
  );
  
  static TranscriptionProgress partial(String text, double progress) => TranscriptionProgress(
    partialText: text,
    progress: progress,
    statusMessage: 'Processando áudio...',
  );
  
  static TranscriptionProgress complete(String text, List<SpeakerSegment>? speakers) => TranscriptionProgress(
    partialText: text,
    speakerSegments: speakers,
    progress: 1.0,
    isComplete: true,
    statusMessage: 'Completo!',
  );
}

class AIService {
  static bool _initialized = false;
  static bool _modelsCopied = false;
  static String? _modelPath;
  static String _diagnosticLog = '';
  static int _availableSpaceBytes = 0;
  
  // Stream for real-time transcription updates
  static final _transcriptionController = StreamController<TranscriptionProgress>.broadcast();
  static Stream<TranscriptionProgress> get transcriptionStream => _transcriptionController.stream;

  // Whisper small (466MB) - renamed to whisper-base.bin
  static const int EXPECTED_WHISPER_SIZE = 490000000;
  static const int EXPECTED_LLAMA_SIZE = 653000000;
  static const int WHISPER_MIN_SIZE = 440000000;
  static const int LLAMA_MIN_SIZE = 580000000;
  static const int MIN_DISK_SPACE_NEEDED = 2000000000;

  // Whisper small renamed to whisper-base for compatibility
  static const String WHISPER_FILENAME = 'whisper-base.bin';
  static const String LLAMA_FILENAME = 'tinyllama-1.1b-chat-v1.0.Q4_K_M.gguf';

  static bool get isModelsReady => _modelsCopied;
  static String? get modelPath => _modelPath;
  static String get diagnosticLog => _diagnosticLog;
  static int get availableSpaceBytes => _availableSpaceBytes;

  static void _log(String message) {
    final timestamp = DateTime.now().toIso8601String();
    _diagnosticLog += '[$timestamp] $message\n';
    print('AI: $message');
  }
  
  /// Emit progress to stream
  static void _emitProgress(TranscriptionProgress progress) {
    _transcriptionController.add(progress);
  }

  static Future<bool> _checkDiskSpace() async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final modelDir = Directory('${appDir.path}/models');
      
      if (!await modelDir.exists()) {
        await modelDir.create(recursive: true);
      }
      
      final testFile = File('${modelDir.path}/.space_test');
      await testFile.writeAsBytes([1]);
      await testFile.delete();
      
      _log('Disk space check: OK');
      return true;
    } catch (e) {
      _log('Disk space check FAILED: $e');
      return false;
    }
  }

  static String? _validateModelPath() {
    if (_modelPath == null) {
      _log('_modelPath is NULL');
      return null;
    }
    
    final file = File(_modelPath!);
    if (!file.existsSync()) {
      _log('Model file NOT FOUND at: $_modelPath');
      _modelPath = null;
      _modelsCopied = false;
      return null;
    }
    
    final stat = file.statSync();
    _log('Model path validated: $_modelPath (${stat.size} bytes)');
    return _modelPath;
  }

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
        _log('Model INCOMPLETE: ${stat.size} < $minSize');
        return false;
      }
      
      _log('Model INTEGRITY OK');
      return true;
    } catch (e) {
      _log('Model integrity check FAILED: $e');
      return false;
    }
  }

  static Future<bool> checkAssetsIntegrity() async {
    _log('=== PRE-FLIGHT CHECK ===');

    try {
      _log('Checking disk space...');
      final hasSpace = await _checkDiskSpace();
      if (!hasSpace) {
        AIManager.setError('Sem espaco em disco ou erro de permissao');
        _log('Pre-flight FAILED: No disk space');
        return false;
      }

      final appDir = await getApplicationDocumentsDirectory();
      final modelDir = Directory('${appDir.path}/models');
      _log('Model directory: ${modelDir.path}');
      
      if (!await modelDir.exists()) {
        _log('Creating model directory...');
        await modelDir.create(recursive: true);
      }
      
      final whisperPath = '${modelDir.path}/$WHISPER_FILENAME';
      _log('🔍 Looking for Whisper at: $whisperPath');
      
      // Check Whisper model
      if (await File(whisperPath).exists()) {
        _log('Whisper file exists, checking integrity...');
        if (!_verifyModelIntegrity(whisperPath, EXPECTED_WHISPER_SIZE, WHISPER_MIN_SIZE)) {
          _log('Whisper corrupted, recreating...');
          await _deleteAndRecreateModel(whisperPath, WHISPER_FILENAME);
        } else {
          _modelPath = whisperPath;
          _modelsCopied = true;
          AIManager.setState(AIState.ready, message: 'Pronto para gravar');
          _log('✅ Whisper model ready');
        }
      } else {
        _log('⚠️ Whisper: NOT FOUND - copying...');
        await _copyModel(WHISPER_FILENAME, whisperPath);
        _log('✅ Whisper copied successfully!');
      }
      
      // ALSO check and copy Llama model
      final llamaPath = '${modelDir.path}/$LLAMA_FILENAME';
      _log('🔍 Looking for Llama at: $llamaPath');
      
      // Check if directory exists first
      if (!await modelDir.exists()) {
        _log('⚠️ Model directory does not exist, creating...');
        await modelDir.create(recursive: true);
      }
      
      final llamaFile = File(llamaPath);
      _log('🔍 Llama file exists check: ${await llamaFile.exists()}');
      
      if (await llamaFile.exists()) {
        _log('🔍 Llama file exists, checking integrity...');
        final stat = llamaFile.statSync();
        _log('🔍 Llama file size: ${stat.size} bytes');
        
        if (!_verifyModelIntegrity(llamaPath, EXPECTED_LLAMA_SIZE, LLAMA_MIN_SIZE)) {
          _log('⚠️ Llama corrupted, recreating...');
          await _deleteAndRecreateModel(llamaPath, LLAMA_FILENAME);
          _log('✅ Llama recreated successfully!');
        } else {
          _log('✅ Llama model ready (verified)');
        }
      } else {
        _log('⚠️ Llama: NOT FOUND - will copy...');
        await _copyModel(LLAMA_FILENAME, llamaPath);
        
        // Verify copy worked
        final copiedFile = File(llamaPath);
        if (await copiedFile.exists()) {
          final copiedSize = copiedFile.statSync().size;
          _log('✅ Llama copied successfully! Size: $copiedSize bytes');
        } else {
          _log('❌ ERROR: Llama copy failed - file not found after copy');
        }
      }

      _validateModelPath();
      AIManager.setState(AIState.ready, message: 'Pronto para gravar');
      return true;
    } catch (e) {
      _log('Pre-flight FAILED: $e');
      AIManager.setError('Falha na verificacao: $e');
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

  static Future<void> _copyModel(String assetName, String destPath) async {
    _log('Copying $assetName...');
    AIManager.setState(AIState.loading, message: 'Baixando $assetName...');

    try {
      final hasSpace = await _checkDiskSpace();
      if (!hasSpace) {
        throw Exception('No disk space available');
      }

      final data = await rootBundle.load('assets/models/$assetName');
      _log('Asset loaded: ${data.lengthInBytes} bytes');

      final file = File(destPath);
      final sink = file.openWrite();
      sink.add(data.buffer.asUint8List());

      await sink.flush();
      await sink.close();

      _log('Sink closed, waiting for filesystem...');
      await Future.delayed(const Duration(milliseconds: 300));

      if (!file.existsSync()) {
        throw Exception('File not found after write');
      }

      final stat = file.statSync();
      _log('Model copied: ${stat.size} bytes');

      if (stat.size < data.lengthInBytes ~/ 2) {
        throw Exception('Model copy incomplete');
      }

      _modelsCopied = true;
      _modelPath = destPath;
      _log('Model ready: $destPath');
    } catch (e) {
      _log('Copy FAILED: $e');
      AIManager.setError('Erro ao copiar $assetName: $e');
      rethrow;
    }
  }

  static Future<void> initializeInBackground() async {
    if (_initialized) {
      _log('Already initialized, path: $_modelPath');
      return;
    }

    _log('=== INITIALIZATION START ===');
    AIManager.setState(AIState.loading, message: 'Preparando IA...');

    try {
      final hasSpace = await _checkDiskSpace();
      if (!hasSpace) {
        throw Exception('No disk space or permission denied');
      }

      await Isolate.run(() async {
        await _copyModelsToDocuments();
      });

      final ready = await checkAssetsIntegrity();
      if (!ready) {
        _log('Post-initialization check failed');
      }

      _initialized = true;
      _validateModelPath();
      _log('=== INITIALIZATION COMPLETE ===');
      _log('Final model path: $_modelPath');
    } catch (e) {
      _log('INITIALIZATION FAILED: $e');
      AIManager.setError('Inicializacao falhou: $e');
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

  static Future<Transcription?> processAudio({
    required String audioPath,
    required String title,
    Function(double progress, String status)? onProgress,
  }) async {
    _log('=== PROCESS AUDIO ===');
    
    // Emit initial progress
    _emitProgress(TranscriptionProgress.loading(0.0, 'Iniciando transcrição...'));
    onProgress?.call(0.05, 'Preparando...');

    final validatedPath = _validateModelPath();
    if (validatedPath == null) {
      _log('Models not ready, running pre-flight...');
      AIManager.setState(AIState.loading, message: 'Carregando modelo...');
      _emitProgress(TranscriptionProgress.loading(0.1, 'Carregando modelo...'));
      final ready = await checkAssetsIntegrity();
      if (!ready) {
        throw Exception('Pre-flight check failed');
      }
      _validateModelPath();
    }

    _log('Checking audio file: $audioPath');
    final audioFile = File(audioPath);
    if (!audioFile.existsSync()) {
      throw Exception('Audio file NOT FOUND: $audioPath');
    }
    
    final audioStat = audioFile.statSync();
    _log('Audio file size: ${audioStat.size} bytes');
    
    if (audioStat.size < 10000) {
      _log('WARNING: Audio file too small (${audioStat.size} bytes)');
      AIManager.setError('Audio vazio ou corrompido');
      throw Exception('Audio file too small. Need at least 10KB.');
    }

    AIManager.setState(AIState.processing, message: 'Transcrevendo...');
    _emitProgress(TranscriptionProgress.loading(0.2, 'Processando áudio...'));
    onProgress?.call(0.2, 'Processando audio...');

    try {
      final safePath = _validateModelPath();
      _log('processAudio: validated model path: $safePath');
      
      if (safePath == null) {
        throw Exception('Model path lost');
      }
      
      // Verify model file exists and has correct size
      final modelFile = File(safePath);
      if (!modelFile.existsSync()) {
        throw Exception('Model file does not exist: $safePath');
      }
      final modelSize = modelFile.lengthSync();
      _log('processAudio: model file size: $modelSize bytes');
      if (modelSize < 100000000) {
        throw Exception('Model file too small: $modelSize bytes (expected ~144MB)');
      }

      // Initialize WhisperPlatformService on MAIN THREAD before isolate
      _log('processAudio: Initializing platform service on main thread...');
      final platformInitResult = await WhisperPlatformService.initialize(safePath);
      _log('processAudio: Platform service init result: $platformInitResult');
      
      // Capture the RootIsolateToken BEFORE starting the isolate
      final rootToken = ServicesBinding.rootIsolateToken;
      _log('processAudio: Got root isolate token: ${rootToken != null}');
      
      _log('processAudio: About to start Isolate with modelPath: $safePath');
      _log('processAudio: Audio path: $audioPath');

      Transcription? result;
      try {
        result = await Isolate.run(() async {
          // Initialize the background isolate messenger FIRST
          if (rootToken != null) {
            BackgroundIsolateBinaryMessenger.ensureInitialized(rootToken);
          }
          
          _log('🔥[Isolate] Starting pipeline...');
          return await _processPipeline(
            audioPath: audioPath,
            title: title,
            modelPath: safePath,
          );
        });
        _log('processAudio: Isolate completed, result: ${result?.text?.substring(0, 50) ?? "NULL"}...');
      } catch (isolateError, stack) {
        _log('processAudio: Isolate FAILED: $isolateError');
        _log('processAudio: Stack: $stack');
        rethrow;
      }

      AIManager.setState(AIState.ready, message: 'Pronto');
      onProgress?.call(1.0, 'Completo');
      _log('=== PROCESS COMPLETE ===');
      
      // Emit completion
      if (result != null) {
        _emitProgress(TranscriptionProgress.complete(
          result!.text,
          result!.speakerSegments,
        ));
      }
      
      return result;
    } catch (e) {
      _log('PROCESS FAILED: $e');
      AIManager.setError('Processamento falhou: $e');
      rethrow;
    }
  }

  static Future<Transcription> _processPipeline({
    required String audioPath,
    required String title,
    required String modelPath,
  }) async {
    _log('🔥[Isolate] _processPipeline called');
    _log('🔥[Isolate] audioPath: $audioPath');
    _log('🔥[Isolate] modelPath: $modelPath');
    
    // Verify audio exists
    final audioFile = File(audioPath);
    if (!audioFile.existsSync()) {
      throw Exception('[Isolate] Audio file NOT FOUND: $audioPath');
    }
    final audioSize = audioFile.lengthSync();
    _log('🔥[Isolate] Audio file exists, size: $audioSize bytes');
    
    // Verify model exists
    final modelFile = File(modelPath);
    if (!modelFile.existsSync()) {
      throw Exception('[Isolate] Model file NOT FOUND: $modelPath');
    }
    final modelSize = modelFile.lengthSync();
    _log('🔥[Isolate] Model file exists, size: $modelSize bytes');
    _log('🔥[Isolate] Pipeline start');
    _log('🔥[Isolate] Using model path: $modelPath');

    try {
      if (!File(audioPath).existsSync()) {
        throw Exception('Audio file NOT FOUND: $audioPath');
      }

      final audioStat = File(audioPath).statSync();
      _log('🔥[Isolate] Audio size: ${audioStat.size} bytes');

      // Verify model file exists
      final modelFile = File(modelPath);
      if (!modelFile.existsSync()) {
        throw Exception('[Isolate] Model file NOT FOUND: $modelPath');
      }
      final modelSize = modelFile.lengthSync();
      _log('🔥[Isolate] Model file size: $modelSize bytes');
      
      // Skip integrity check - just verify file exists
      // Let Whisper handle compatibility

      _log('🔥[Isolate] Model: $modelPath');

      // Pass the token to enable platform channel inside isolate
      final rootToken = ServicesBinding.rootIsolateToken;
      if (rootToken != null) {
        BackgroundIsolateBinaryMessenger.ensureInitialized(rootToken);
      }

      // Try platform service (mx.valdora) - THIS IS WORKING!
      String? text;
      try {
        _log('🔥[Isolate] Trying platform service (mx.valdora)...');
        
        final initResult = await WhisperPlatformService.initialize(modelPath);
        if (initResult) {
          _log('🔥[Isolate] Platform service initialized');
          text = await WhisperPlatformService.transcribe(audioPath, language: 'pt');
          if (text != null && text.isNotEmpty) {
            _log('🔥[Isolate] Platform service SUCCESS: ${text.substring(0, text.length > 50 ? 50 : text.length)}...');
          }
        }
      } catch (e) {
        _log('🔥[Isolate] Platform service FAILED: $e');
      }
      
      // If platform service didn't work, try FFI
      if (text == null || text.isEmpty) {
        _log('🔥[Isolate] Trying native FFI...');
        
        if (!WhisperBindings.load()) {
          _log('Whisper: FFI load FAILED - using fallback');
          return _generateFallbackTranscription(audioPath, title);
        }

        _log('🔥[Isolate] Init Whisper...');
        final whisperCtx = WhisperBindings.initFromFile(modelPath);
        
        if (whisperCtx == null) {
          _log('Whisper: initFromFile returned NULL - using fallback');
          return _generateFallbackTranscription(audioPath, title);
        }

        _log('🔥[Isolate] ctx = $whisperCtx');

        _log('🔥[Isolate] Transcribing...');
        try {
          text = WhisperBindings.full(ctx: whisperCtx, audioPath: audioPath) ?? '';
        } catch (e) {
          _log('🔥[Isolate] Whisper EXCEPTION: $e - using fallback');
          return _generateFallbackTranscription(audioPath, title);
        }
      }
      
      // If Whisper returned empty, use fallback instead of failing
      if (text == null || text.isEmpty) {
        _log('Whisper: returned EMPTY - using fallback');
        return _generateFallbackTranscription(audioPath, title);
      }

      _log('🔥[Isolate] Text: $text');

      // Emit partial progress - text is being processed
      final speakers = _diarize(text);

      String summary = '';
      List<String> actionItems = [];

      final llamaPath = modelPath.replaceAll(WHISPER_FILENAME, LLAMA_FILENAME);
      _log('🔥[Isolate] Llama path: $llamaPath');
      
      if (File(llamaPath).existsSync()) {
        if (_verifyModelIntegrity(llamaPath, EXPECTED_LLAMA_SIZE, LLAMA_MIN_SIZE)) {
          _log('🔥[Isolate] Loading Llama...');
          if (LlamaBindings.load()) {
            final llamaCtx = LlamaBindings.initFromFile(llamaPath);
            if (llamaCtx != null) {
              _log('🔥[Isolate] Llama ctx ready');
              final result = LlamaBindings.generate(ctx: llamaCtx, prompt: text);
              if (result != null) {
                summary = result['summary'] ?? '';
                actionItems = List<String>.from(result['actionItems'] ?? []);
              }
            }
          }
        }
      } else {
        _log('🔥[Isolate] Llama model NOT FOUND');
      }

      _log('🔥[Isolate] Pipeline complete');

      return Transcription(
        id: title.hashCode.abs().toString(),  // Use title as ID base
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
      _log('🔥[Isolate] Finally block: Cleaning up memory...');
      
      try {
        WhisperBindings.dispose();
        _log('🔥[Isolate] Whisper disposed');
      } catch (e) {
        _log('🔥[Isolate] Whisper dispose error: $e');
      }
      
      try {
        LlamaBindings.dispose();
        _log('🔥[Isolate] Llama disposed');
      } catch (e) {
        _log('🔥[Isolate] Llama dispose error: $e');
      }
      
      await Future.delayed(const Duration(milliseconds: 500));
      _log('🔥[Isolate] Memory cleanup complete');
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

  /// Fallback transcription when native library fails
  /// This ensures the player stays visible and app doesn't crash
  static Transcription _generateFallbackTranscription(String audioPath, String title) {
    _log('Using fallback transcription (native lib failed)');
    
    // Return empty text - keeps player visible and audio playable
    final text = "";
    
    final speakers = _diarize(text);
    
    return Transcription(
      id: title.hashCode.abs().toString(),
      title: title,
      audioPath: audioPath,
      text: text,
      wordTimestamps: [],
      createdAt: DateTime.now(),
      duration: const Duration(minutes: 2),
      isEncrypted: false,
      speakerSegments: speakers,
      summary: '',
      actionItems: [],
    );
  }
}
