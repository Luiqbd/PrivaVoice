import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Platform channel wrapper for mx.valdora whisper-android library
/// This provides 100% offline transcription without external APIs
class WhisperPlatformService {
  static const _channel = MethodChannel('com.privavoice/whisper');
  
  static bool _isInitialized = false;
  static String? _modelPath;
  
  /// Initialize the whisper context with model file (called from main thread)
  static Future<bool> initialize(String modelPath) async {
    if (_isInitialized) return true;
    
    try {
      _modelPath = modelPath;
      
      final file = File(modelPath);
      if (!await file.exists()) {
        print('WhisperPlatform: Model file not found: $modelPath');
        return false;
      }
      
      // CRITICAL: Force PT during initialization at engine level
      final result = await _channel.invokeMethod<bool>('init', {
        'modelPath': modelPath,
        'language': 'pt',
      });
      
      _isInitialized = result ?? false;
      print('WhisperPlatform: Initialize result: $_isInitialized');
      return _isInitialized;
    } catch (e) {
      print('WhisperPlatform: Initialize error: $e');
      return false;
    }
  }
  
  /// Transcribe audio file (must be WAV 16kHz mono)
  /// CRITICAL FIX: Enhanced language forcing using anchor prompt
  static Future<String?> transcribe(String audioPath, {String language = 'pt'}) async {
    if (!_isInitialized) {
      debugPrint('WhisperPlatform: Not initialized');
      return null;
    }
    
    try {
      final audioFile = File(audioPath);
      if (!await audioFile.exists()) return null;
      
      // CRITICAL: Force PT language via initialPrompt
      final result = await _channel.invokeMethod<String>('transcribe', {
        'audioPath': audioPath,
        'language': 'pt',
        'initialPrompt': 'Olá, sou o Luis Fernando, estou gravando em português brasileiro.',
      });
      
      debugPrint('WhisperPlatform: Result received');
      return result;
    } catch (e) {
      debugPrint('WhisperPlatform: Transcribe error: $e');
      return null;
    }
  }
  
  /// Release resources
  static Future<void> release() async {
    if (!_isInitialized) return;
    try {
      await _channel.invokeMethod('release');
      _isInitialized = false;
      _modelPath = null;
    } catch (e) {
      print('WhisperPlatform: Release error: $e');
    }
  }
  
  static bool get isAvailable => _isInitialized;
}
