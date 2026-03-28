import 'dart:async';
import 'dart:isolate';

import 'package:path_provider/path_provider.dart';
import '../../../domain/entities/transcription.dart';

/// Whisper FFI Service - On-device speech recognition
/// Uses background isolates for processing to maintain 60fps UI
class WhisperService {
  static const String _modelName = 'whisper-base';
  bool _isModelLoaded = false;
  
  /// Initialize Whisper model in background isolate
  Future<void> initialize() async {
    if (_isModelLoaded) return;
    
    // Load model from assets in background
    await _loadModel();
    _isModelLoaded = true;
  }
  
  Future<void> _loadModel() async {
    // In production: load actual Whisper model from assets
    // For now, we'll prepare the structure
    final directory = await getApplicationDocumentsDirectory();
    final modelPath = '${directory.path}/models/$_modelName.bin';
    // Model loading would happen here with actual FFI
  }
  
  /// Transcribe audio file with word-level timestamps for karaoke effect
  /// Returns word timestamps for immediate seekTo functionality
  Future<TranscriptionResult> transcribe(String audioPath) async {
    if (!_isModelLoaded) {
      await initialize();
    }
    
    // Run transcription in background isolate to maintain 60fps
    return await Isolate.run(() async {
      // Simulated transcription - in production this would call whisper.cpp via FFI
      await Future.delayed(const Duration(seconds: 2)); // Simulate processing
      
      // Return mock result with word-level timestamps
      return _generateMockTranscription(audioPath);
    });
  }
  
  /// Extract word-level timestamps for karaoke effect
  List<WordTimestamp> extractWordTimestamps(String text, Duration duration) {
    final words = text.split(' ');
    final wordCount = words.length;
    final durationMs = duration.inMilliseconds;
    final avgWordDuration = durationMs ~/ wordCount;
    
    final timestamps = <WordTimestamp>[];
    int currentTime = 0;
    
    for (int i = 0; i < words.length; i++) {
      final wordDuration = (i < words.length - 1) 
          ? avgWordDuration 
          : durationMs - currentTime;
      
      timestamps.add(WordTimestamp(
        word: words[i],
        startTime: Duration(milliseconds: currentTime),
        endTime: Duration(milliseconds: currentTime + wordDuration),
        confidence: 0.95 - (i * 0.005), // Decreasing confidence
      ));
      
      currentTime += wordDuration;
    }
    
    return timestamps;
  }
  
  /// Get word index for seekTo functionality
  int getWordIndexAtPosition(List<WordTimestamp> timestamps, Duration position) {
    for (int i = 0; i < timestamps.length; i++) {
      if (position >= timestamps[i].startTime && 
          position < timestamps[i].endTime) {
        return i;
      }
    }
    return timestamps.length - 1;
  }
  
  /// Dispose resources
  void dispose() {
    _isModelLoaded = false;
  }
  
  /// Generate mock transcription for demo
  TranscriptionResult _generateMockTranscription(String audioPath) {
    const text = "Olá, bem-vindo ao PrivaVoice. Este é um teste de reconhecimento de voz.";
    final wordTimestamps = extractWordTimestamps(text, const Duration(seconds: 5));
    
    return TranscriptionResult(
      text: text,
      wordTimestamps: wordTimestamps,
      language: 'pt',
      duration: const Duration(seconds: 5),
    );
  }
}

/// Result from Whisper transcription
class TranscriptionResult {
  final String text;
  final List<WordTimestamp> wordTimestamps;
  final String language;
  final Duration duration;
  
  const TranscriptionResult({
    required this.text,
    required this.wordTimestamps,
    required this.language,
    required this.duration,
  });
}
