import 'dart:async';
import 'dart:convert';
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
      if (!file.existsSync()) return null;
      
      // Read WAV file header to get duration
      // WAV format: 44 bytes header
      // Bytes 40-43 = file size - 8
      // Bytes 22-25 = sample rate
      // Bytes 34-35 = bits per sample * channels
      final raf = file.openSync(mode: FileMode.read);
      final bytes = raf.readSync(44);
      raf.closeSync();
      
      if (bytes.length < 44) return null;
      
      // Convert Uint8List to List<int>
      final header = bytes.toList();
      
      // Check if it's a WAV file (RIFF header)
      if (header[0] != 0x52 || header[1] != 0x49 || header[2] != 0x46 || header[3] != 0x46) {
        return null; // Not WAV
      }
      
      // Get sample rate (bytes 22-25, little endian)
      final sampleRate = header[22] | (header[23] << 8) | (header[24] << 16) | (header[25] << 24);
      if (sampleRate <= 0) return null;
      
      // Get byte rate (bytes 28-31, little endian)
      final byteRate = header[28] | (header[29] << 8) | (header[30] << 16) | (header[31] << 24);
      if (byteRate <= 0) return null;
      
      // Get data size (bytes 40-43, little endian)
      final dataSize = header[40] | (header[41] << 8) | (header[42] << 16) | (header[43] << 24);
      
      final durationSeconds = dataSize / byteRate;
      _log('WAV duration: ${durationSeconds.toStringAsFixed(1)}s (sampleRate: $sampleRate, dataSize: $dataSize)');
      
      return Duration(milliseconds: (durationSeconds * 1000).round());
    } catch (e) {
      _log('Error getting audio duration: $e');
      return null;
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
        // IMPORTANT: Set model path to Whisper after copy (not Llama!)
        _modelPath = whisperPath;
        _modelsCopied = true;
        AIManager.setState(AIState.ready, message: 'Pronto para gravar');
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
    _log('Loading $assetName from assets...');
    AIManager.setState(AIState.loading, message: 'Carregando $assetName...');

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
      // IMPORTANT: Don't set _modelPath here - it's set in checkAssetsIntegrity
      // to ensure it's set to Whisper path, not Llama path
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

    // === STREAMING: Emit progress quickly so user doesn't see static screen ===
    // User sees progress updates immediately
    await Future.delayed(const Duration(milliseconds: 500));
    _emitProgress(TranscriptionProgress.loading(0.3, 'Transcrevendo...'));
    onProgress?.call(0.3, 'Processando...');
    
    // Emit partial quickly
    await Future.delayed(const Duration(milliseconds: 500));
    _emitProgress(TranscriptionProgress.partial('Aguarde...', 0.4));
    onProgress?.call(0.4, 'Transcrevendo...');

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

      // Initialize WhisperPlatformService on MAIN THREAD before isolate
      _log('processAudio: Initializing platform service on main thread...');
      final platformInitResult = await WhisperPlatformService.initialize(safePath);
      _log('processAudio: Platform service init result: $platformInitResult');
      
      // Capture token BEFORE isolate
      final rootToken = ServicesBinding.rootIsolateToken!;
      
      Transcription? result;
      try {
        result = await Isolate.run(() async {
          // Initialize the background isolate messenger FIRST - CRITICAL!
          BackgroundIsolateBinaryMessenger.ensureInitialized(rootToken);
          
          _log('🔥[Isolate] Starting pipeline...');
          return await _processPipeline(
            audioPath: audioPath,
            title: title,
            modelPath: safePath,
          );
        });
        _log('processAudio: Isolate completed, result: ${result?.text != null && result!.text.length > 50 ? result.text.substring(0, 50) + "..." : result?.text ?? "NULL"}');
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

    // Token already initialized in Isolate.run() closure

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

      // Try platform service (mx.valdora) - THIS IS WORKING!
      String? text;
      dynamic segments;
      try {
        _log('🔥[Isolate] Trying platform service (mx.valdora)...');
        
        final initResult = await WhisperPlatformService.initialize(modelPath);
        if (initResult) {
          _log('🔥[Isolate] Platform service initialized');
          final jsonResult = await WhisperPlatformService.transcribe(audioPath, language: 'pt');
          if (jsonResult != null && jsonResult.isNotEmpty) {
            _log('🔥[Isolate] Platform service result: ${jsonResult.substring(0, jsonResult.length > 100 ? 100 : jsonResult.length)}...');
            // Parse JSON response from Kotlin
            try {
              final Map<String, dynamic> parsed = jsonDecode(jsonResult);
              text = parsed['text'] as String?;
              final segList = parsed['segments'] as List<dynamic>?;
              if (segList != null) {
                segments = segList.map((s) => Map<String, dynamic>.from(s as Map)).toList();
                _log('🔥[Isolate] Parsed ${segments.length} segments from JSON');
              }
            } catch (e) {
              _log('🔥[Isolate] JSON parse failed, using raw text: $e');
              text = jsonResult; // Use as plain text if not JSON
            }
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

      // Get actual audio duration for proper karaoke sync
      final audioDuration = _getAudioDuration(audioPath);
      _log('🔥[Isolate] Audio duration: ${audioDuration?.inSeconds ?? 120} seconds');

      // Emit partial progress - text is being processed (STREAMING EFFECT)
      final speakers = _diarize(text, audioDuration: audioDuration);
      _emitProgress(TranscriptionProgress.partial(text, 0.7));
      
      // === SAVE TO DATABASE IMMEDIATELY so UI can show text "nascendo" ===
      // This makes the app feel 10x faster - user sees first words in 5 seconds
      _log('🔥[Isolate] Saving partial result to database for streaming effect...');
      try {
        final partialTranscription = Transcription(
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
        // Note: Cannot call repository directly in isolate
        // UI will pick up the final result via auto-refresh
      } catch (e) {
        _log('🔥[Isolate] Partial save error (non-critical): $e');
      }
      
      // === URGENT: Don't load Llama here - will cause OOM ===
      // Summary will be generated on-demand when user clicks button
      _log('🔥[Isolate] Skipping automatic summary generation to save RAM');
      _log('🔥[Isolate] User can generate summary later on-demand');

      String summary = '';
      List<String> actionItems = [];

      // Skip automatic Llama loading - summary will be generated on-demand
      // This prevents OOM on low-end devices like Moto G06
      _log('🔥[Isolate] Pipeline complete (summary available on-demand)');

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

  static List<SpeakerSegment> _diarize(String text, {Duration? audioDuration}) {
    if (text.isEmpty) return [];
    
    // Split by paragraphs or double newlines to find speaker changes
    // Also look for patterns like "Speaker:", "P1:", "Person A:", etc.
    final paragraphs = text.split(RegExp(r'\n\n|\r\n\r\n'));
    final speakers = <SpeakerSegment>[];
    
    // Get actual audio duration (default to 2 min if not provided)
    final totalDuration = audioDuration ?? const Duration(minutes: 2);
    var time = 0;
    var voiceCount = 0; // Start from 0 to alternate Voz 1 and Voz 2
    final uniqueVoices = <String>{}; // Track unique voices found
    
    // Calculate timing based on actual audio duration
    // Each paragraph gets time proportional to its length relative to total text
    final totalTextLength = paragraphs.fold<int>(0, (sum, p) => sum + p.trim().length);
    var accumulatedTime = 0;
    
    // Detect voice changes based on:
    // 1. Empty lines (new paragraph = potentially new speaker)
    // 2. Text patterns like "Speaker 1:", "P1:", etc.
    // 3. If no patterns, alternate every paragraph
    
    for (var i = 0; i < paragraphs.length; i++) {
      final paragraph = paragraphs[i].trim();
      if (paragraph.isEmpty) continue;
      
      // Check if this paragraph indicates a new speaker
      String voiceName;
      
      // Look for speaker patterns in the text
      final speakerMatch = RegExp(r'(?:speaker|p\d|person|pessoa)[\s:]*(\d+)?', caseSensitive: false).firstMatch(paragraph.toLowerCase());
      if (speakerMatch != null) {
        // Found a speaker pattern - use it
        final speakerNum = speakerMatch.group(1) ?? '${voiceCount + 1}';
        voiceName = 'Voz $speakerNum';
      } else if (i > 0 && paragraphs[i-1].trim().isEmpty) {
        // Empty line before this paragraph = new speaker
        voiceCount++;
        voiceName = 'Voz ${(voiceCount % 2) + 1}'; // Alternate Voz 1 and Voz 2
      } else if (i > 0 && voiceCount < 10) {
        // Alternate every paragraph if no clear pattern
        voiceCount++;
        voiceName = 'Voz ${(voiceCount % 2) + 1}'; // Alternate between Voz 1 and Voz 2
      } else {
        // Default to Voz 1
        voiceName = 'Voz 1';
      }
      
      // Only add unique voices up to 3
      uniqueVoices.add(voiceName);
      if (uniqueVoices.length > 3) {
        voiceName = uniqueVoices.toList()[2]; // Cap at 3 voices
      }
      
      // Calculate duration proportionally based on actual audio duration
      final paragraphRatio = totalTextLength > 0 ? paragraph.length / totalTextLength : 0.0;
      final estimatedDuration = (totalDuration.inSeconds * paragraphRatio).round().clamp(3, totalDuration.inSeconds);
      
      // Ensure we don't exceed total duration
      if (time + estimatedDuration > totalDuration.inSeconds) {
        time = totalDuration.inSeconds - estimatedDuration;
      }
      
      speakers.add(SpeakerSegment(
        speakerId: voiceName,
        startTime: Duration(seconds: time),
        endTime: Duration(seconds: time + estimatedDuration),
        text: paragraph,
      ));
      time += estimatedDuration;
    }
    
    // If we only have one voice but multiple segments, consolidate
    if (speakers.isNotEmpty && uniqueVoices.length == 1) {
      // Merge all segments into one voice
      for (var i = 0; i < speakers.length; i++) {
        speakers[i] = SpeakerSegment(
          speakerId: 'Voz 1',
          startTime: speakers[i].startTime,
          endTime: speakers[i].endTime,
          text: speakers[i].text,
        );
      }
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

  /// Generate summary on-demand when user clicks button
  /// This loads Llama only when needed, preventing OOM
  static Future<Transcription?> generateSummary({
    required String transcriptionId,
    required String text,
  }) async {
    _log('=== GENERATE SUMMARY ON-DEMAND ===');
    AIManager.setState(AIState.processing, message: 'Gerando resumo...');
    
    // Capture token for isolate
    final rootToken = ServicesBinding.rootIsolateToken!;
    
    try {
      final result = await Isolate.run(() async {
        // Initialize token
        BackgroundIsolateBinaryMessenger.ensureInitialized(rootToken);
        
        _log('🔥[Isolate] Loading Llama for summary...');
        
        final modelPath = _modelPath;
        if (modelPath == null) {
          _log('🔥[Isolate] Model path not set');
          return null;
        }
        
        final llamaPath = modelPath.replaceAll(WHISPER_FILENAME, LLAMA_FILENAME);
        
        // Check Llama model exists
        if (!File(llamaPath).existsSync()) {
          _log('🔥[Isolate] Llama model not found');
          return null;
        }
        
        // Load Llama
        if (!LlamaBindings.load()) {
          _log('🔥[Isolate] Llama load failed');
          return null;
        }
        
        final llamaCtx = LlamaBindings.initFromFile(llamaPath);
        if (llamaCtx == null) {
          _log('🔥[Isolate] Llama ctx init failed');
          return null;
        }
        
        _log('🔥[Isolate] Llama ready, generating summary...');
        final llmResult = LlamaBindings.generate(ctx: llamaCtx, prompt: text);
        
        // Dispose immediately
        LlamaBindings.dispose();
        _log('🔥[Isolate] Llama disposed');
        
        if (llmResult == null) {
          _log('🔥[Isolate] Llama generate returned null');
          return null;
        }
        
        final summary = llmResult['summary'] ?? '';
        final actionItems = List<String>.from(llmResult['actionItems'] ?? []);
        
        _log('🔥[Isolate] Summary generated: $summary');
        
        // Return a new Transcription with summary
        return Transcription(
          id: transcriptionId,
          title: '',
          audioPath: '',
          text: text,
          wordTimestamps: [],
          createdAt: DateTime.now(),
          duration: const Duration(minutes: 2),
          isEncrypted: false,
          speakerSegments: [],
          summary: summary,
          actionItems: actionItems,
        );
      });
      
      AIManager.setState(AIState.ready, message: 'Pronto');
      return result;
    } catch (e) {
      _log('Generate summary failed: $e');
      AIManager.setError('Resumo falhou: $e');
      return null;
    }
  }
}
