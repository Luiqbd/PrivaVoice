import 'dart:async';
import '../../domain/entities/transcription.dart';
import 'ai_service.dart';
import '../ai/ai_state.dart';

/// Transcription service with state machine
class TranscriptionService {
  static Transcription? _current;
  
  static Transcription? get current => _current;
  static bool get isReady => AIManager.isReady;
  static bool get isProcessing => AIManager.isProcessing;
  static String get status => AIManager.statusMessage;
  static double get progress => AIManager.progress;
  
  /// Process audio with state machine
  static Future<Transcription?> process({
    required String audioPath,
    required String title,
    Function(double progress, String status)? onLoading,
  }) async {
    if (!isReady) {
      print('Cannot process - AI not ready. State: ${AIManager.state}');
      return null;
    }
    
    if (isProcessing) {
      print('Already processing...');
      return null;
    }
    
    try {
      final result = await AIService.processAudio(
        audioPath: audioPath,
        title: title,
        onProgress: onLoading,
      );
      
      _current = result;
      return result;
    } catch (e) {
      print('TranscriptionService error: $e');
      rethrow;
    }
  }
  
  /// Get diagnostics for support
  static String getDiagnostics() {
    return AIService.getDiagnostics();
  }
  
  static void clear() {
    _current = null;
  }
}
