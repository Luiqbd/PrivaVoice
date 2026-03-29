import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import '../../domain/entities/transcription.dart';
import '../ai/native/whisper_bindings.dart';
import '../ai/native/llama_bindings.dart';

/// AI Service with Isolate processing - UI stays responsive
class AIService {
  static bool _initialized = false;
  static bool _modelsCopied = false;
  static String? _modelPath;
  
  /// Check if models are ready
  static bool get isModelsReady => _modelsCopied;
  static String? get modelPath => _modelPath;

  /// Initialize models in background - returns immediately
  static Future<void> initializeInBackground() async {
    if (_initialized) return;
    
    print('AI: Starting background initialization...');
    
    // Run model copy in isolate to keep UI responsive
    await Isolate.run(() async {
      print('AI [Isolate]: Starting model copy...');
      await _copyModelsToDocuments();
      print('AI [Isolate]: Models copied successfully');
    });
    
    _initialized = true;
  }

  /// Copy models to documents - called from isolate
  static Future<void> _copyModelsToDocuments() async {
    final appDir = await getApplicationDocumentsDirectory();
    final modelDir = Directory('${appDir.path}/models');
    
    if (!await modelDir.exists()) {
      await modelDir.create(recursive: true);
    }
    
    // === WHISPER ===
    final whisperAsset = 'assets/models/whisper-base.bin';
    final whisperDest = '${modelDir.path}/whisper-base.bin';
    
    print('AI: Checking Whisper at: $whisperDest');
    
    // Check if already copied
    if (await File(whisperDest).exists()) {
      final stat = await File(whisperDest).stat();
      print('AI: Whisper already exists, size = ${stat.size} bytes');
      if (stat.size > 10000000) {
        _modelPath = whisperDest;
        _modelsCopied = true;
        print('AI: ✅ Whisper model ready');
        return;
      }
    }
    
    print('AI: Copying Whisper from assets...');
    try {
      final data = await rootBundle.load(whisperAsset);
      print('AI: Whisper asset loaded, size = ${data.lengthInBytes} bytes');
      
      await File(whisperDest).writeAsBytes(data.buffer.asUint8List());
      
      // Verify copy
      final stat = await File(whisperDest).stat();
      print('AI: Whisper copied, verified size = ${stat.size} bytes');
      
      if (stat.size > 10000000) {
        _modelPath = whisperDest;
        _modelsCopied = true;
        print('AI: ✅ Whisper model ready');
      }
    } catch (e) {
      print('AI: ERROR copying Whisper: $e');
    }
    
    // === LLAMA ===
    final llamaAsset = 'assets/models/tinyllama-1.1b-chat-v1.0.Q4_K_M.gguf';
    final llamaDest = '${modelDir.path}/tinyllama-1.1b-chat-v1.0.Q4_K_M.gguf';
    
    print('AI: Checking Llama...');
    if (await File(llamaDest).exists()) {
      final stat = await File(llamaDest).stat();
      print('AI: Llama already exists, size = ${stat.size} bytes');
    }
  }

  /// Process audio in isolate - keeps UI responsive
  static Future<Transcription?> processInBackground({
    required String audioPath,
    required String title,
    Function(double)? onProgress,
  }) async {
    print('AI: Processing in background...');
    
    if (onProgress != null) onProgress(0.1);
    
    // Ensure models copied
    if (!_modelsCopied || _modelPath == null) {
      print('AI: Models not ready, initializing...');
      await initializeInBackground();
    }
    
    if (onProgress != null) onProgress(0.3);
    
    // Process in isolate
    final result = await Isolate.run(() async {
      return await _processPipeline(
        audioPath: audioPath,
        title: title,
      );
    });
    
    if (onProgress != null) onProgress(1.0);
    
    return result;
  }

  /// Real pipeline - runs in isolate
  static Future<Transcription> _processPipeline({
    required String audioPath,
    required String title,
  }) async {
    print('AI [Isolate]: Pipeline start');
    print('AI [Isolate]: audioPath = $audioPath');
    
    if (!File(audioPath).existsSync()) {
      throw Exception('Audio file NOT FOUND');
    }
    
    if (_modelPath == null) {
      throw Exception('Model path is NULL');
    }
    
    print('AI [Isolate]: Loading Whisper...');
    
    // Load Whisper
    if (!WhisperBindings.load()) {
      throw Exception('Failed to load libwhisper.so');
    }
    
    print('AI [Isolate]: Model path = $_modelPath');
    
    // Init model
    final ctx = WhisperBindings.initFromFile(_modelPath!);
    if (ctx == null) {
      throw Exception('Whisper initFromFile returned NULL');
    }
    
    print('AI [Isolate]: ctx = ${ctx.address}');
    
    // Transcribe
    final text = WhisperBindings.full(ctx: ctx, audioPath: audioPath);
    if (text == null || text.isEmpty) {
      throw Exception('Whisper returned empty transcription');
    }
    
    print('AI [Isolate]: Transcription = "$text"');
    
    WhisperBindings.dispose();
    
    // Diarization
    final speakers = _diarize(text);
    
    // Llama summary
    String summary = '';
    List<String> actionItems = [];
    
    print('AI [Isolate]: Processing with Llama...');
    if (LlamaBindings.load()) {
      final llamaCtx = LlamaBindings.initFromFile(
        _modelPath!.replaceAll('whisper-base.bin', 'tinyllama-1.1b-chat-v1.0.Q4_K_M.gguf')
      );
      if (llamaCtx != null) {
        final result = LlamaBindings.generate(ctx: llamaCtx, prompt: text);
        if (result != null) {
          summary = result['summary'] ?? '';
          actionItems = List<String>.from(result['actionItems'] ?? []);
        }
        LlamaBindings.dispose();
      }
    }
    
    print('AI [Isolate]: Pipeline complete');
    
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
}
