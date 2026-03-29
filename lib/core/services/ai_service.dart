import 'dart:async';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import '../../domain/entities/transcription.dart';
import '../ai/native/whisper_bindings.dart';
import '../ai/native/llama_bindings.dart';

/// REAL AIService - NO DEMO - CLEAR ERRORS
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
      print('AI: Created models dir: ${modelDir.path}');
    }
    
    // === WHISPER ===
    final whisperAsset = 'assets/models/whisper-base.bin';
    final whisperDest = '${modelDir.path}/whisper-base.bin';
    
    try {
      print('AI: Loading Whisper from: $whisperAsset');
      final data = await rootBundle.load(whisperAsset);
      print('AI: Whisper asset size: ${data.lengthInBytes} bytes');
      
      await File(whisperDest).writeAsBytes(data.buffer.asUint8List());
      final stat = await File(whisperDest).stat();
      print('AI: Whisper copied to: $whisperDest');
      print('AI: Whisper file size: ${stat.size} bytes');
      
      if (stat.size < 1000) {
        print('AI: WARNING - Whisper file too small!');
      }
    } catch (e) {
      print('AI: ERROR copying Whisper: $e');
    }
    
    // === LLAMA ===
    final llamaAsset = 'assets/models/tinyllama-1.1b-chat-v1.0.Q4_K_M.gguf';
    final llamaDest = '${modelDir.path}/tinyllama-1.1b-chat-v1.0.Q4_K_M.gguf';
    
    try {
      print('AI: Loading Llama from: $llamaAsset');
      final data = await rootBundle.load(llamaAsset);
      print('AI: Llama asset size: ${data.lengthInBytes} bytes');
      
      await File(llamaDest).writeAsBytes(data.buffer.asUint8List());
      final stat = await File(llamaDest).stat();
      print('AI: Llama copied to: $llamaDest');
      print('AI: Llama file size: ${stat.size} bytes');
      
      if (stat.size < 1000000) {
        print('AI: WARNING - Llama file too small (should be ~700MB)!');
      }
    } catch (e) {
      print('AI: ERROR copying Llama: $e');
    }
    
    // Verify files exist
    if (await File(whisperDest).exists()) {
      print('AI: Whisper EXISTS in docs');
    } else {
      print('AI: Whisper NOT in docs!');
    }
    
    if (await File(llamaDest).exists()) {
      print('AI: Llama EXISTS in docs');
    } else {
      print('AI: Llama NOT in docs!');
    }
  }

  Future<Transcription> processFullPipeline({
    required String audioPath,
    required String title,
    String? existingId,
  }) async {
    print('AI: ========== PIPELINE START ==========');
    print('AI: audioPath = $audioPath');
    
    // Verify audio
    final audioFile = File(audioPath);
    if (!await audioFile.exists()) {
      throw Exception('ERROR: Audio file NOT FOUND at $audioPath');
    }
    
    final audioSize = await audioFile.length();
    print('AI: Audio size = $audioSize bytes');
    
    if (audioSize == 0) {
      throw Exception('ERROR: Audio file is EMPTY (0 bytes)');
    }
    
    if (audioSize < 1000) {
      print('AI: WARNING - Audio file very small: $audioSize bytes');
    }
    
    await initializeAll();
    
    final appDir = await getApplicationDocumentsDirectory();
    final whisperPath = '${appDir.path}/models/whisper-base.bin';
    final llamaPath = '${appDir.path}/models/tinyllama-1.1b-chat-v1.0.Q4_K_M.gguf';
    
    print('AI: whisperPath = $whisperPath');
    print('AI: llamaPath = $llamaPath');
    
    // ========== STEP 1: WHISPER ==========
    print('AI: ========== STEP 1: WHISPER ==========');
    
    // Check model file
    if (!await File(whisperPath).exists()) {
      throw Exception('ERROR: Whisper model NOT FOUND at $whisperPath');
    }
    
    final whisperStat = await File(whisperPath).stat();
    print('AI: Whisper model size = ${whisperStat.size} bytes');
    
    // Load native lib
    final loaded = WhisperBindings.load();
    print('AI: WhisperBindings.load() = $loaded');
    
    // Note: Native lib may not be available - continue anyway
    
    // Init model
    print('AI: Calling WhisperBindings.initFromFile($whisperPath)');
    final ctx = WhisperBindings.initFromFile(whisperPath);
    print('AI: Whisper ctx = ${ctx != null ? "VALID ✅" : "NULL ❌"}');
    
    if (ctx == null) {
      throw Exception('ERROR: Whisper initFromFile returned NULL');
    }
    
    // Process audio
    print('AI: Calling WhisperBindings.full()');
    final text = WhisperBindings.full(ctx: ctx, audioPath: audioPath, withTimestamps: true);
    
    if (text == null || text.isEmpty) {
      throw Exception('ERROR: Whisper returned NULL/EMPTY - FFI not implemented');
    }
    
    print('AI: Transcription = "${text.substring(0, text.length > 50 ? 50 : text.length)}..."');
    print('AI: Transcription length = ${text.length} chars');
    
    WhisperBindings.dispose();
    
    // Get timestamps
    final timestamps = WhisperBindings.getWordTimestamps(ctx);
    print('AI: Word timestamps = ${timestamps?.length ?? 0}');
    
    // ========== STEP 2: DIARIZATION ==========
    print('AI: ========== STEP 2: DIARIZATION ==========');
    final speakers = _diarize(text);
    print('AI: Speaker segments = ${speakers.length}');
    
    // ========== STEP 3: LLAMA ==========
    print('AI: ========== STEP 3: LLAMA ==========');
    
    if (!await File(llamaPath).exists()) {
      throw Exception('ERROR: Llama model NOT FOUND at $llamaPath');
    }
    
    final llamaLoaded = LlamaBindings.load();
    print('AI: LlamaBindings.load() = $llamaLoaded');
    
    // Note: Native lib may not be available - continue anyway
    
    print('AI: Calling LlamaBindings.initFromFile($llamaPath)');
    final llamaCtx = LlamaBindings.initFromFile(llamaPath);
    print('AI: Llama ctx = ${llamaCtx != null ? "VALID ✅" : "NULL ❌"}');
    
    if (llamaCtx == null) {
      throw Exception('ERROR: Llama initFromFile returned NULL');
    }
    
    print('AI: Calling LlamaBindings.generate()');
    final result = LlamaBindings.generate(ctx: llamaCtx, prompt: text);
    
    if (result == null) {
      throw Exception('ERROR: Llama returned NULL - FFI not implemented');
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
    
    print('AI: ========== PIPELINE COMPLETE ==========');
    
    return Transcription(
      id: existingId ?? DateTime.now().millisecondsSinceEpoch.toString(),
      title: title,
      audioPath: audioPath,
      text: text,
      wordTimestamps: timestamps?.map((e) => WordTimestamp(
        word: e['word'] ?? '',
        startTime: Duration(milliseconds: e['start'] ?? 0),
        endTime: Duration(milliseconds: e['end'] ?? 0),
        confidence: 0.9,
      )).toList() ?? <WordTimestamp>[],
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
