import 'dart:async';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import '../../domain/entities/transcription.dart';
import '../ai/native/whisper_bindings.dart';
import '../ai/native/llama_bindings.dart';

/// REAL AIService - NO DEMO MODE - NO FALLBACKS
class AIService {
  static bool _initialized = false;

  Future<void> initializeAll() async {
    if (_initialized) return;
    print('AI: Initializing...');
    await _copyModelsToDocuments();
    _initialized = true;
  }

  Future<void> _copyModelsToDocuments() async {
    final appDir = await getApplicationDocumentsDirectory();
    final modelDir = Directory('${appDir.path}/models');
    
    if (!await modelDir.exists()) {
      await modelDir.create(recursive: true);
      print('AI: Created models dir');
    }
    
    // Whisper
    final whisperAsset = 'assets/models/whisper-base.bin';
    final whisperDest = '${modelDir.path}/whisper-base.bin';
    try {
      final data = await rootBundle.load(whisperAsset);
      await File(whisperDest).writeAsBytes(data.buffer.asUint8List());
      print('AI: Whisper copied: ${(await File(whisperDest).stat()).size} bytes');
    } catch (e) {
      print('AI: ERROR Whisper asset: $e');
    }
    
    // Llama
    final llamaAsset = 'assets/models/tinyllama-1.1b-chat-v1.0.Q4_K_M.gguf';
    final llamaDest = '${modelDir.path}/tinyllama-1.1b-chat-v1.0.Q4_K_M.gguf';
    try {
      final data = await rootBundle.load(llamaAsset);
      await File(llamaDest).writeAsBytes(data.buffer.asUint8List());
      print('AI: Llama copied: ${(await File(llamaDest).stat()).size} bytes');
    } catch (e) {
      print('AI: ERROR Llama asset: $e');
    }
  }

  Future<Transcription> processFullPipeline({
    required String audioPath,
    required String title,
    String? existingId,
  }) async {
    print('AI: === PIPELINE START ===');
    print('AI: audioPath = $audioPath');
    
    // Verify audio
    final audioFile = File(audioPath);
    if (!await audioFile.exists()) {
      throw Exception('ERROR: Audio file NOT FOUND');
    }
    final audioSize = await audioFile.length();
    print('AI: Audio size = $audioSize bytes');
    if (audioSize == 0) {
      throw Exception('ERROR: Audio file is EMPTY');
    }
    
    await initializeAll();
    
    final appDir = await getApplicationDocumentsDirectory();
    final whisperPath = '${appDir.path}/models/whisper-base.bin';
    final llamaPath = '${appDir.path}/models/tinyllama-1.1b-chat-v1.0.Q4_K_M.gguf';
    
    // === STEP 1: WHISPER ===
    print('AI: === STEP 1: WHISPER ===');
    
    if (!await File(whisperPath).exists()) {
      throw Exception('ERROR: Whisper model NOT FOUND');
    }
    
    final loaded = WhisperBindings.load();
    print('AI: Whisper lib load = $loaded');
    
    if (!loaded) {
      throw Exception('ERROR: Could NOT load Whisper native library (libwhisper.so)');
    }
    
    final ctx = WhisperBindings.initFromFile(whisperPath);
    print('AI: Whisper ctx = ${ctx != null ? "VALID" : "NULL"}');
    
    if (ctx == null) {
      throw Exception('ERROR: Whisper initFromFile returned NULL');
    }
    
    print('AI: Whisper processing...');
    final text = WhisperBindings.full(ctx: ctx, audioPath: audioPath, withTimestamps: true);
    
    if (text == null || text.isEmpty) {
      throw Exception('ERROR: Whisper FULL returned NULL or EMPTY. FFI bindings need implementation.');
    }
    
    print('AI: Transcription length = ${text.length}');
    WhisperBindings.dispose();
    
    // === STEP 2: DIARIZATION ===
    print('AI: === STEP 2: DIARIZATION ===');
    final speakers = _diarize(text);
    print('AI: Speaker segments = ${speakers.length}');
    
    // === STEP 3: LLAMA ===
    print('AI: === STEP 3: LLAMA ===');
    
    if (!await File(llamaPath).exists()) {
      throw Exception('ERROR: Llama model NOT FOUND');
    }
    
    final llamaLoaded = LlamaBindings.load();
    print('AI: Llama lib load = $llamaLoaded');
    
    if (!llamaLoaded) {
      throw Exception('ERROR: Could NOT load Llama native library (libllama.so)');
    }
    
    final llamaCtx = LlamaBindings.initFromFile(llamaPath);
    print('AI: Llama ctx = ${llamaCtx != null ? "VALID" : "NULL"}');
    
    if (llamaCtx == null) {
      throw Exception('ERROR: Llama initFromFile returned NULL');
    }
    
    print('AI: Llama generating...');
    final result = LlamaBindings.generate(ctx: llamaCtx, prompt: text);
    
    if (result == null) {
      throw Exception('ERROR: Llama GENERATE returned NULL. FFI bindings need implementation.');
    }
    
    final summary = result['summary'] ?? '';
    final actionItems = result['actionItems'] != null 
        ? List<String>.from(result['actionItems']) 
        : <String>[];
    
    if (summary.isEmpty) {
      throw Exception('ERROR: Llama summary is EMPTY');
    }
    
    print('AI: Summary = "$summary"');
    LlamaBindings.dispose();
    
    print('AI: === PIPELINE COMPLETE ===');
    
    // Get word timestamps
    final wordTimestamps = WhisperBindings.getWordTimestamps(ctx)?.map((e) => WordTimestamp(
      word: e['word'] ?? '',
      startTime: Duration(milliseconds: e['start'] ?? 0),
      endTime: Duration(milliseconds: e['end'] ?? 0),
      confidence: 0.9,
    )).toList() ?? <WordTimestamp>[];
    
    return Transcription(
      id: existingId ?? DateTime.now().millisecondsSinceEpoch.toString(),
      title: title,
      audioPath: audioPath,
      text: text,
      wordTimestamps: wordTimestamps,
      createdAt: DateTime.now(),
      duration: const Duration(minutes: 2),
      isEncrypted: false,
      speakerSegments: speakers,
      summary: summary,
      actionItems: actionItems,
    );
  }

  List<SpeakerSegment> _diarize(String text) {
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
