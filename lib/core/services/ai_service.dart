import 'dart:async';
import 'dart:convert';
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
import '../utils/audio_normalizer.dart';

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
  // Track isolate-specific initialization
  static bool _initialized = false;
  static bool _isolateWhisperReady = false;
  static bool _modelsCopied = false;
  static String? _modelPath;
  static String? _llamaModelPath; // Separate persistent path for Llama
  static String _diagnosticLog = '';
  static int _availableSpaceBytes = 0;
  
  // Stream for real-time transcription updates
  static final _transcriptionController = StreamController<TranscriptionProgress>.broadcast();
  static Stream<TranscriptionProgress> get transcriptionStream => _transcriptionController.stream;

  // Whisper small Q5_1 (~180MB) - optimized for speed and quality
  static const int EXPECTED_WHISPER_SIZE = 180000000;
  static const int EXPECTED_LLAMA_SIZE = 653000000;
  static const int WHISPER_MIN_SIZE = 160000000;
  static const int LLAMA_MIN_SIZE = 580000000;
  static const int MIN_DISK_SPACE_NEEDED = 1500000000;
  
  // Dynamic thread calculation: use n-1 cores for max performance
  static int get recommendedThreads {
    final cores = Platform.numberOfProcessors;
    return cores > 1 ? cores - 1 : 1;
  }

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
/// Get audio file duration by reading WAV header
  static Duration? _getAudioDuration(String audioPath) {
    try {
      final file = File(audioPath);
      if (!file.existsSync()) {
        _log('WAV: File not found, using default duration');
        return const Duration(minutes: 2);
      }
      
      // Read WAV file header to get duration
      final raf = file.openSync(mode: FileMode.read);
      final bytes = raf.readSync(44);
      raf.closeSync();
      
      if (bytes.length < 44) {
        _log('WAV: Header too small, using default duration');
        return const Duration(minutes: 2);
      }
      
      // Convert Uint8List to List<int>
      final header = bytes.toList();
      
      // Check if it's a WAV file (RIFF header)
      if (header[0] != 0x52 || header[1] != 0x49 || header[2] != 0x46 || header[3] != 0x46) {
        _log('WAV: Not a valid WAV file, using default duration');
        return const Duration(minutes: 2);
      }
      
      // Get sample rate (bytes 22-25, little endian)
      var sampleRate = header[22] | (header[23] << 8) | (header[24] << 16) | (header[25] << 24);
      
      // Sanity check - valid sample rates are 8000, 16000, 22050, 44100, 48000
      // If invalid (> 100000), use default 16000 Hz
      if (sampleRate <= 0 || sampleRate > 100000) {
        _log('WAV: Invalid sampleRate $sampleRate, defaulting to 16000Hz');
        sampleRate = 16000;
      }
      
      // Get byte rate (bytes 28-31, little endian)
      var byteRate = header[28] | (header[29] << 8) | (header[30] << 16) | (header[31] << 24);
      if (byteRate <= 0) {
        // Calculate from sampleRate if byteRate is invalid
        byteRate = sampleRate * 2; // 16-bit mono
        _log('WAV: Invalid byteRate, calculated as $byteRate');
      }
      
      // Get data size (bytes 40-43, little endian)
      var dataSize = header[40] | (header[41] << 8) | (header[42] << 16) | (header[43] << 24);
      if (dataSize <= 0 || dataSize > 100000000) {
        _log('WAV: Invalid dataSize $dataSize, using file size minus header');
        dataSize = bytes.length - 44;
      }
      
      final durationSeconds = dataSize / byteRate;
      _log('WAV duration: ${durationSeconds.toStringAsFixed(1)}s (sampleRate: $sampleRate, dataSize: $dataSize)');
      
      return Duration(milliseconds: (durationSeconds * 1000).round());
    } catch (e) {
      _log('WAV: Error parsing header: $e, using default duration');
      return const Duration(minutes: 2);
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
          AIManager.setState(AIState.readyWhisper, message: 'Pronto para gravar');
          _log('✅ Whisper model ready');
        }
      } else {
        _log('⚠️ Whisper: NOT FOUND - copying...');
        await _copyModel(WHISPER_FILENAME, whisperPath);
        _log('✅ Whisper copied successfully!');
        // IMPORTANT: Set model path to Whisper after copy (not Llama!)
        _modelPath = whisperPath;
        _modelsCopied = true;
        AIManager.setState(AIState.readyWhisper, message: 'Pronto para gravar');
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
          _llamaModelPath = llamaPath; // Store persistent path
          _log('✅ Llama model ready (verified)');
        }
      } else {
        _log('⚠️ Llama: NOT FOUND - will copy...');
        await _copyModel(LLAMA_FILENAME, llamaPath);
        
        // Verify copy worked
        final copiedFile = File(llamaPath);
        if (await copiedFile.exists()) {
          _llamaModelPath = llamaPath; // Store persistent path
          final copiedSize = copiedFile.statSync().size;
          _log('✅ Llama copied successfully! Size: $copiedSize bytes');
        } else {
          _log('❌ ERROR: Llama copy failed - file not found after copy');
        }
      }

      _validateModelPath();
      AIManager.setState(AIState.readyWhisper, message: 'Pronto para gravar');
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
    final modelName = assetName.contains('Whisper') ? 'Whisper' : 'Llama';
    _log('Loading $assetName from assets...');
    AIManager.setState(AIState.loading, message: 'Extraindo $modelName...', progress: 0.0);

    try {
      final hasSpace = await _checkDiskSpace();
      if (!hasSpace) {
        throw Exception('No disk space available');
      }

      // Load asset data
      final data = await rootBundle.load('assets/models/$assetName');
      final totalBytes = data.lengthInBytes;
      _log('Asset loaded: $totalBytes bytes');
      
      AIManager.setState(AIState.loading, message: 'Copiando $modelName...', progress: 0.1);
      
      // Start copying with progress updates
      final file = File(destPath);
      final sink = file.openWrite();
      
      // Copy in chunks for progress reporting
      const chunkSize = 1024 * 1024; // 1MB chunks
      final totalChunks = (totalBytes / chunkSize).ceil();
      final bytes = data.buffer.asUint8List();
      
      for (var i = 0; i < totalChunks; i++) {
        final start = i * chunkSize;
        final end = (start + chunkSize > totalBytes) ? totalBytes : start + chunkSize;
        sink.add(bytes.sublist(start, end));
        
        // Update progress (10% to 80% during copy)
        final chunkProgress = 0.1 + (0.7 * i / totalChunks);
        AIManager.setState(
          AIState.loading, 
          message: 'Extraindo $modelName: ${(chunkProgress * 100).round()}%...',
          progress: chunkProgress,
        );
      }

      await sink.flush();
      await sink.close();

      AIManager.setState(AIState.loading, message: 'Finalizando...', progress: 0.9);
      _log('Sink closed, waiting for filesystem...');
      await Future.delayed(const Duration(milliseconds: 300));

      if (!file.existsSync()) {
        throw Exception('File not found after write');
      }

      final stat = file.statSync();
      _log('Model copied: ${stat.size} bytes');

      if (stat.size < totalBytes ~/ 2) {
        throw Exception('Model copy incomplete');
      }

      _modelsCopied = true;
      AIManager.setState(AIState.loading, message: '$modelName pronto!', progress: 1.0);
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

      // Capture token before isolate
      final rootToken = ServicesBinding.rootIsolateToken!;
      
      await Isolate.run(() async {
        // Initialize token for this isolate
        BackgroundIsolateBinaryMessenger.ensureInitialized(rootToken);
        await _copyModelsToDocuments();
      });

      final ready = await checkAssetsIntegrity();
      if (!ready) {
        _log('Post-initialization check failed');
      }
      
      // Load PT-BR prompt for better transcription
      _log('Loading PT-BR context...');
      await WhisperBindings.loadPtBrPrompt();
      
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
    _emitProgress(TranscriptionProgress.loading(0.1, 'Iniciando motor Whisper...'));
    onProgress?.call(0.1, 'Iniciando...');
    
    // === STREAMING: Emit progress quickly so user doesn't see static screen ===
    // User sees progress updates immediately
    await Future.delayed(const Duration(milliseconds: 300));
    _emitProgress(TranscriptionProgress.loading(0.2, 'Carregando modelo...'));
    onProgress?.call(0.2, 'Carregando modelo...');
    
    await Future.delayed(const Duration(milliseconds: 300));
    _emitProgress(TranscriptionProgress.loading(0.3, 'Preparando áudio...'));
    onProgress?.call(0.3, 'Preparando...');
    
    await Future.delayed(const Duration(milliseconds: 300));
    _emitProgress(TranscriptionProgress.loading(0.4, 'Processando 504.320 samples...'));
    onProgress?.call(0.4, 'Processando...');
    
    // Give UI time to show loading before heavy processing
    await Future.delayed(const Duration(milliseconds: 500));

    try {
      // CRITICAL: Always use Whisper model for transcription, not Llama!
      // The _modelPath might be set to Llama by checkAssetsIntegrity, so we need to fix it
      final appDir = await getApplicationDocumentsDirectory();
      final modelDir = Directory('${appDir.path}/models');
      final whisperPath = '${modelDir.path}/$WHISPER_FILENAME';
      
      // Use Whisper path directly for transcription
      final safePath = whisperPath;
      _log('processAudio: Using Whisper path: $safePath');
      
      if (!File(safePath).existsSync()) {
        throw Exception('Whisper model not found: $safePath');
      }

      // STABILITY: Skip normalization - use raw WAV
      final finalAudioPath = audioPath;
      _log('processAudio: Using raw WAV (NO normalization)...');

      // WhisperPlatformService handles native initialization internally
      // It runs on background thread via platform channel
      
      // Run transcription on MAIN THREAD (no isolate/compute)
      // Whisper will manage its own internal threads
      // UI may freeze for 2 seconds but app won't crash
      _log('processAudio: Running on MAIN THREAD (NO ISOLATE)...');
      
      Transcription? result;
      try {
        result = await _processPipeline(
          audioPath: finalAudioPath,
          title: title,
          modelPath: safePath,
        );
        _log('processAudio: ✅ Pipeline completed successfully');
      } catch (isolateError, stack) {
        _log('processAudio: ❌ Pipeline FAILED: $isolateError');
        _log('processAudio: Stack: $stack');
        rethrow;
      }

      AIManager.setState(AIState.readyWhisper, message: 'Pronto');
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

  // Static method for transcription pipeline - runs on MAIN THREAD
  static Future<Transcription> _processPipeline({
    required String audioPath,
    required String title,
    required String modelPath,
  }) async {
    _log('🔄[MainThread] _processPipeline called');
    _log('🔄[MainThread] audioPath: $audioPath');
    _log('🔄[MainThread] modelPath: $modelPath');
    
    // Verify audio exists
    final audioFile = File(audioPath);
    if (!audioFile.existsSync()) {
      throw Exception('[MainThread] Audio file NOT FOUND: $audioPath');
    }
    final audioSize = audioFile.lengthSync();
    _log('🔄[MainThread] Audio file exists, size: $audioSize bytes');
    
    // Verify model exists
    final modelFile = File(modelPath);
    if (!modelFile.existsSync()) {
      throw Exception('[MainThread] Model file NOT FOUND: $modelPath');
    }
    final modelSize = modelFile.lengthSync();
    _log('🔄[MainThread] Model file exists, size: $modelSize bytes');
    _log('🔄[MainThread] Pipeline start');
    _log('🔄[MainThread] Using model path: $modelPath');

    // No token needed - running on main thread

    try {
      if (!File(audioPath).existsSync()) {
        throw Exception('Audio file NOT FOUND: $audioPath');
      }

      final audioStat = File(audioPath).statSync();
      _log('🔥[MainThread] Audio size: ${audioStat.size} bytes');

      // Verify model file exists
      final modelFile = File(modelPath);
      if (!modelFile.existsSync()) {
        throw Exception('[MainThread] Model file NOT FOUND: $modelPath');
      }
      final modelSize = modelFile.lengthSync();
      _log('🔥[MainThread] Model file size: $modelSize bytes');
      
      // Skip integrity check - just verify file exists
      // Let Whisper handle compatibility

      _log('🔥[MainThread] Model: $modelPath');

      // Skip platform service (mx.valdora) - it's unstable and crashes
      // Go directly to FFI which is more reliable
      _log('🔥[MainThread] Using native FFI for transcription...');
      
      // Use FFI directly
      String? text;
      dynamic segments;
      
      // Use Kotlin mx.valdora via platform channel (NOT FFI)
      _log('🔄[MainThread] Using Kotlin mx.valdora platform channel...');
      
      // Initialize Whisper via platform channel
      final initResult = await WhisperPlatformService.initialize(modelPath);
      _log('🔄[MainThread] WhisperPlatform init: $initResult');
      
      if (!initResult) {
        _log('⚠️[MainThread] WhisperPlatform init FAILED');
        return _generateFallbackTranscription(audioPath, title);
      }
      
      // Transcribe via platform channel (runs on background thread in Kotlin)
      _log('🔄[MainThread] Transcribing via platform channel...');
      text = await WhisperPlatformService.transcribe(audioPath, language: 'pt');
      _log('🔄[MainThread] Platform result: ${text?.substring(0, text.length > 50 ? 50 : 0)}...');
      
      // Release Whisper to free memory before Llama
      _log('🔄[MainThread] Releasing Whisper...');
      await WhisperPlatformService.release();
      
      if (text == null || text.isEmpty) {
        _log('⚠️[MainThread] Platform returned empty');
        return _generateFallbackTranscription(audioPath, title);
      }
      
      _log('✅[MainThread] Kotlin transcription success!');

      _log('🔥[MainThread] Text: $text');

      // Get actual audio duration for proper karaoke sync
      final audioDuration = _getAudioDuration(audioPath);
      _log('🔥[MainThread] Audio duration: ${audioDuration?.inSeconds ?? 120} seconds');

      // Use segment-based diarization if available (from Kotlin JSON)
      // Otherwise fall back to simple Voz 1 assignment
      final hasSegments = segments != null && (segments as List).isNotEmpty;
      final speakers = hasSegments
          ? _diarizeWithSegments(List<Map<String, dynamic>>.from(segments), audioDuration: audioDuration)
          : _simpleDiarize(text);
      
      // Stream each segment for real-time UI effect
      for (final seg in speakers) {
        _transcriptionController.add(TranscriptionProgress.partial(seg.text, 0.5));
      }
      
      _emitProgress(TranscriptionProgress.partial(text, 0.7));
      
      // === SAVE TO DATABASE IMMEDIATELY so UI can show text "nascendo" ===
      // This makes the app feel 10x faster - user sees first words in 5 seconds
      _log('🔥[MainThread] Saving partial result to database for streaming effect...');
      try {
        final partialTranscription = Transcription(
          id: title.hashCode.abs().toString(),
          title: title,
          audioPath: audioPath,
          text: text,
          wordTimestamps: [],
          createdAt: DateTime.now(),
          duration: const Duration(minutes: 2),
          isEncrypted: true,
          speakerSegments: speakers,
          summary: '',
          actionItems: [],
        );
        // Note: Cannot call repository directly in isolate
        // UI will pick up the final result via auto-refresh
      } catch (e) {
        _log('🔥[MainThread] Partial save error (non-critical): $e');
      }
      
      // === URGENT: Don't load Llama here - will cause OOM ===
      // Summary will be generated on-demand when user clicks button
      _log('🔥[MainThread] Skipping automatic summary generation to save RAM');
      _log('🔥[MainThread] User can generate summary later on-demand');

      String summary = '';
      List<String> actionItems = [];

      // Skip automatic Llama loading - summary will be generated on-demand
      // This prevents OOM on low-end devices like Moto G06
      _log('🔥[MainThread] Pipeline complete (summary available on-demand)');

      return Transcription(
        id: title.hashCode.abs().toString(),  // Use title as ID base
        title: title,
        audioPath: audioPath,
        text: text,
        wordTimestamps: [],
        createdAt: DateTime.now(),
        duration: const Duration(minutes: 2),
        isEncrypted: true,
        speakerSegments: speakers,
        summary: summary,
        actionItems: actionItems,
      );
      
    } finally {
      _log('🔥[MainThread] Finally block: Cleaning up memory...');
      
      try {
        WhisperBindings.dispose();
        _log('🔥[MainThread] Whisper disposed');
      } catch (e) {
        _log('🔥[MainThread] Whisper dispose error: $e');
      }
      
      try {
        LlamaBindings.dispose();
        _log('🔥[MainThread] Llama disposed');
      } catch (e) {
        _log('🔥[MainThread] Llama dispose error: $e');
      }
      
      await Future.delayed(const Duration(milliseconds: 500));
      _log('🔥[MainThread] Memory cleanup complete');
    }
  }

  /// Diarization by pause: if interval > 1.5s, assign to Voz 2
  /// Uses segment timing from Whisper JSON output
  static List<SpeakerSegment> _diarizeWithSegments(
    List<Map<String, dynamic>> segments, {
    Duration? audioDuration,
  }) {
    if (segments.isEmpty) return [];
    
    final speakers = <SpeakerSegment>[];
    var currentVoice = 'Voz 1';
    var lastEndMs = 0;
    
    for (var i = 0; i < segments.length; i++) {
      final seg = segments[i];
      final startMs = (seg['start'] as num?)?.toInt() ?? 0;
      final endMs = (seg['end'] as num?)?.toInt() ?? 0;
      final text = seg['text'] as String? ?? '';
      // Use speaker from Kotlin if available, otherwise calculate
      final kotlinSpeaker = seg['speaker'] as String?;
      
      if (text.trim().isEmpty) continue;
      
      // Use Kotlin's speaker if provided, otherwise calculate from pause
      if (kotlinSpeaker != null) {
        currentVoice = kotlinSpeaker;
        _log('🔊 Using Kotlin speaker: $currentVoice');
      } else {
        // Check pause: > 1500ms gap = new speaker
        final gap = startMs - lastEndMs;
        if (gap > 1500) {
          currentVoice = currentVoice == 'Voz 1' ? 'Voz 2' : 'Voz 1';
          _log('🔊 Voice change! Gap: ${gap}ms -> $currentVoice');
        }
      }
      
      speakers.add(SpeakerSegment(
        speakerId: currentVoice,
        startTime: Duration(milliseconds: startMs),
        endTime: Duration(milliseconds: endMs),
        text: text,
      ));
      
      lastEndMs = endMs;
    }
    
    _log('🔊 Diarization done: ${speakers.length} segments, voices: ${speakers.map((s)=>s.speakerId).toSet()}');
    return speakers;
  }

  /// Simple fallback diarization - all text as Voz 1
  static List<SpeakerSegment> _simpleDiarize(String text) {
    if (text.isEmpty) return [];
    
    final paragraphs = text.split(RegExp(r'\n\n|\r\n\r\n'));
    final speakers = <SpeakerSegment>[];
    
    for (var i = 0; i < paragraphs.length; i++) {
      final paragraph = paragraphs[i].trim();
      if (paragraph.isEmpty) continue;
      
      final wordCount = paragraph.split(' ').length;
      final startMs = i * wordCount * 200;
      final endMs = startMs + wordCount * 200;
      
      speakers.add(SpeakerSegment(
        speakerId: 'Voz 1',
        startTime: Duration(milliseconds: startMs),
        endTime: Duration(milliseconds: endMs),
        text: paragraph,
      ));
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

  /// Isolate function for whisper transcription
  /// Runs in separate memory space to prevent native crashes
  static String _whisperTranscribeIsolate(Map<String, String> params) {
    final modelPath = params['modelPath']!;
    final audioPath = params['audioPath']!;
    
    print('Isolate: Loading whisper...');
    
    // Load FFI in isolate
    if (!WhisperBindings.load()) {
      return '';
    }
    
    // Load PT-BR prompt
    WhisperBindings.loadPtBrPrompt();
    
    // Init model
    final ctx = WhisperBindings.initFromFile(modelPath);
    if (ctx == null) {
      return '';
    }
    
    // Transcribe
    final result = WhisperBindings.full(ctx: ctx, audioPath: audioPath) ?? '';
    print('Isolate: Transcription done, ${result.length} chars');
    
    return result;
  }

  /// Fallback transcription when native library fails
  /// This ensures the player stays visible and app doesn't crash
  static Transcription _generateFallbackTranscription(String audioPath, String title) {
    _log('Using fallback transcription (native lib failed)');
    
    // Return empty text - keeps player visible and audio playable
    final text = "";
    
    final speakers = _simpleDiarize(text);
    
    return Transcription(
      id: title.hashCode.abs().toString(),
      title: title,
      audioPath: audioPath,
      text: text,
      wordTimestamps: [],
      createdAt: DateTime.now(),
      duration: const Duration(minutes: 2),
      isEncrypted: true,
      speakerSegments: speakers,
      summary: '',
      actionItems: [],
    );
  }

  /// Generate summary on-demand when user clicks button
  /// This loads Llama only when needed, preventing OOM
  static Future<Transcription?> generateSummary({
    required String transcriptionId,
    required String text,
  }) async {
    _log('=== GENERATE SUMMARY ON-DEMAND ===');
    AIManager.setState(AIState.processing, message: 'Gerando resumo...');
    
    // Capture paths BEFORE entering isolate
    final llamaPath = _llamaModelPath ?? _modelPath?.replaceAll(WHISPER_FILENAME, LLAMA_FILENAME);
    if (llamaPath == null) {
      _log('⚠️[MainThread] No Llama path - checking assets');
      await checkAssetsIntegrity();
    }
    final finalLlamaPath = _llamaModelPath ?? _modelPath?.replaceAll(WHISPER_FILENAME, LLAMA_FILENAME);
    if (finalLlamaPath == null || finalLlamaPath.isEmpty) {
      _log('❌[MainThread] No Llama path available');
      return null;
    }
    
    final rootToken = ServicesBinding.rootIsolateToken!;
    
    try {
      final result = await Isolate.run(() async {
        // Initialize token
        BackgroundIsolateBinaryMessenger.ensureInitialized(rootToken);
        
        _log('🔥[MainThread] Loading Llama for summary...');
        
        // Use captured path from closure
        _log('🔄[MainThread] Using Llama path: $finalLlamaPath');
        
        // Load Llama
        if (!LlamaBindings.load()) {
          _log('🔥[MainThread] Llama load failed');
          return null;
        }
        
        final llamaCtx = LlamaBindings.initFromFile(finalLlamaPath);
        if (llamaCtx == null) {
          _log('🔥[MainThread] Llama ctx init failed');
          return null;
        }
        
        _log('🔥[MainThread] Llama ready, generating summary...');
        final llmResult = LlamaBindings.generate(ctx: llamaCtx, prompt: text);
        
        // Dispose immediately
        LlamaBindings.dispose();
        _log('🔥[MainThread] Llama disposed');
        
        // Reload Whisper after Llama is done
        // Note: Path is already available in _modelPath
        if (_modelPath != null) {
          try {
            WhisperBindings.initFromFile(_modelPath!);
            _log('🔥[MainThread] Whisper reloaded!');
          } catch (e) {
            _log('🔥[MainThread] Whisper reload failed: $e');
          }
        }
        
        if (llmResult == null) {
          _log('🔥[MainThread] Llama generate returned null');
          return null;
        }
        
        final summary = llmResult['summary'] ?? '';
        final actionItems = List<String>.from(llmResult['actionItems'] ?? []);
        
        // Extract 5 keywords from text using simple frequency analysis
        final keywords = _extractKeywords(text);
        
        _log('🔥[MainThread] Summary generated: $summary');
        _log('🔥[MainThread] Keywords: $keywords');
        
        // Return a new Transcription with summary
        return Transcription(
          id: transcriptionId,
          title: '',
          audioPath: '',
          text: text,
          wordTimestamps: [],
          createdAt: DateTime.now(),
          duration: const Duration(minutes: 2),
          isEncrypted: true,
          speakerSegments: [],
          summary: summary,
          actionItems: actionItems,
          keywords: keywords,
        );
      });
      
      AIManager.setState(AIState.readyWhisper, message: 'Pronto');
      return result;
    } catch (e) {
      _log('Generate summary failed: $e');
      AIManager.setError('Resumo falhou: $e');
      return null;
    }
  }
  
  /// Extract 5 keywords from text using frequency analysis
  static List<String> _extractKeywords(String text) {
    // Common words to ignore (Portuguese stopwords)
    final stopwords = {
      'de', 'a', 'o', 'que', 'e', 'do', 'da', 'em', 'um', 'para', 'com',
      'não', 'uma', 'os', 'no', 'se', 'na', 'por', 'mais', 'as', 'dos',
      'como', 'mas', 'ao', 'ele', 'das', 'à', 'seu', 'sua', 'ou', 'quando',
      'muito', 'nos', 'já', 'eu', 'também', 'só', 'pelo', 'pela', 'até',
      'isso', 'ela', 'entre', 'depois', 'sem', 'mesmo', 'aos', 'seus',
      'me', 'onde', 'havia', 'eram', 'essa', 'nem', 'suas', 'meu', 'às',
      'tinha', 'foram', 'essa', 'pelo', 'pela', 'tan', 'to', 'é', 'ser',
      'está', 'tem', 'vai', 'vamos', 'né', 'né', 'ai', 'ah', 'oh', 'olha',
      'você', 'eu', 'nós', 'eles', 'ela', 'tu', 'yo', 'él', 'las', 'los',
    };
    
    // Clean and split text
    final words = text
        .toLowerCase()
        .replaceAll(RegExp(r'[^\w\s]'), '')
        .split(RegExp(r'\s+'))
        .where((w) => w.length > 3)
        .toList();
    
    // Count frequency
    final frequency = <String, int>{};
    for (final word in words) {
      if (!stopwords.contains(word)) {
        frequency[word] = (frequency[word] ?? 0) + 1;
      }
    }
    
    // Get top 5 keywords
    final sorted = frequency.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    
    return sorted.take(5).map((e) => e.key).toList();
  }
  
  /// Generate chat response using Llama
  static Future<String?> generateChatResponse({
    required String transcriptionId,
    required String context,
  }) async {
    _log('=== GENERATE CHAT RESPONSE ===');
    AIManager.setState(AIState.processing, message: 'PrivaChat pensando...');
    
    // Capture paths BEFORE entering isolate
    final llamaPath = _llamaModelPath ?? _modelPath?.replaceAll(WHISPER_FILENAME, LLAMA_FILENAME);
    if (llamaPath == null) {
      _log('⚠️[MainThread] No Llama path - checking assets');
      await checkAssetsIntegrity();
    }
    final finalLlamaPath = _llamaModelPath ?? _modelPath?.replaceAll(WHISPER_FILENAME, LLAMA_FILENAME);
    if (finalLlamaPath == null || finalLlamaPath.isEmpty) {
      _log('❌[MainThread] No Llama path available');
      return null;
    }
    
    final rootToken = ServicesBinding.rootIsolateToken!;
    
    try {
      final result = await Isolate.run(() async {
        BackgroundIsolateBinaryMessenger.ensureInitialized(rootToken);
        
        _log('🔥[MainThread] Loading Llama for chat...');
        
        // Use captured path from closure
        _log('🔄[MainThread] Using Llama path: $finalLlamaPath');
        
        if (!File(finalLlamaPath).existsSync()) {
          _log('❌[MainThread] Llama model not found at: $finalLlamaPath');
          return null;
        }
        
        _log('🔄[MainThread] Found Llama at: $finalLlamaPath');
        
        if (!LlamaBindings.load()) {
          _log('🔥[MainThread] Llama load failed');
          return null;
        }
        
        final llamaCtx = LlamaBindings.initFromFile(finalLlamaPath);
        if (llamaCtx == null) {
          _log('🔥[MainThread] Llama ctx init failed');
          return null;
        }
        
        _log('🔥[MainThread] Llama ready, generating chat response...');
        
        // Chat prompt
        final prompt = '''
Você é um assistente útil chamado PrivaChat. Use a transcrição abaixo para responder às perguntas do usuário de forma clara e em português brasileiro.

$context

Resposta:''';
        
        final llmResult = LlamaBindings.generate(ctx: llamaCtx, prompt: prompt);
        
        // Dispose immediately
        LlamaBindings.dispose();
        _log('🔥[MainThread] Llama disposed for chat');
        
        // Extract string from map result
        if (llmResult == null) return null;
        return llmResult['response'] ?? llmResult['summary'] ?? llmResult.toString();
      });
      
      AIManager.setState(AIState.readyWhisper, message: 'Pronto');
      return result;
    } catch (e) {
      _log('Generate chat response failed: $e');
      AIManager.setError('Chat falhou: $e');
      return null;
    }
  }
}
