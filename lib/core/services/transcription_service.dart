import 'dart:async';
import '../../domain/entities/transcription.dart';
import 'ai_service.dart';

/// Transcription service - handles audio processing with loading UI
class TranscriptionService {
  static Transcription? _current;
  static bool _isProcessing = false;
  static double _progress = 0.0;
  static String _status = 'Pronto';
  
  static Transcription? get current => _current;
  static bool get isProcessing => _isProcessing;
  static double get progress => _progress;
  static String get status => _status;
  
  /// Start processing with loading callback
  static Future<Transcription?> process({
    required String audioPath,
    required String title,
    Function(double progress, String status)? onLoading,
  }) async {
    if (_isProcessing) {
      print('Already processing...');
      return null;
    }
    
    _isProcessing = true;
    _progress = 0.0;
    
    try {
      onLoading?.call(0.1, 'Preparando IA offline...');
      _status = 'Carregando modelos';
      
      if (!AIService.isModelsReady) {
        onLoading?.call(0.2, 'Baixando modelo Whisper (144MB)...');
        await AIService.initializeInBackground();
      }
      
      onLoading?.call(0.4, 'Carregando modelo na memória...');
      
      final result = await AIService.processInBackground(
        audioPath: audioPath,
        title: title,
        onProgress: (p) {
          _progress = 0.4 + (p * 0.6);
          onLoading?.call(_progress, 'Transcrevendo áudio...');
        },
      );
      
      _current = result;
      _progress = 1.0;
      _status = 'Completo';
      
      return result;
    } catch (e) {
      _status = 'Erro: $e';
      print('TranscriptionService error: $e');
      rethrow;
    } finally {
      _isProcessing = false;
    }
  }
  
  static void clear() {
    _current = null;
    _progress = 0.0;
    _status = 'Pronto';
  }
}
