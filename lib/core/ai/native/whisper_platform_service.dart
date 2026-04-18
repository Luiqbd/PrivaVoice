import 'dart:io';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

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
      
      // Check if model file exists and get file size
      final file = File(modelPath);
      if (!await file.exists()) {
        print('WhisperPlatform: Model file not found: $modelPath');
        return false;
      }
      
      final fileSize = await file.length();
      print('WhisperPlatform: Model file size: $fileSize bytes');
      
      // Model must be at least 100MB
      const minValidSize = 100 * 1024 * 1024;
      if (fileSize < minValidSize) {
        print('WhisperPlatform: Model file too small: $fileSize bytes');
        return false;
      }
      
      print('WhisperPlatform: Model file verified, initializing...');
      
      // Initialize via platform channel - pass modelPath so Kotlin creates context
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
  /// CRITICAL: Force PT via prompt appended to audio path comment
  static Future<String?> transcribe(String audioPath, {String language = 'pt'}) async {
    if (!_isInitialized) {
      print('WhisperPlatform: Not initialized');
      return null;
    }
    
    try {
      final audioFile = File(audioPath);
      if (!await audioFile.exists()) {
        print('WhisperPlatform: Audio file not found: $audioPath');
        return null;
      }
      
      // CRITICAL: Force PT language by passing prompt in the request
      // The mx.valdora library checks for language in params
      final result = await _channel.invokeMethod<String>('transcribe', {
        'audioPath': audioPath,
        'language': 'pt',  // FORCE Portuguese - ignore whatever was passed
        'prompt': 'pt-BR spoken language transcription' // Force via prompt
      });
      
      print('WhisperPlatform: Transcribe result: ${result != null && result.length > 50 ? result.substring(0, 50) + "..." : result ?? "null"}');
      return result;
    } catch (e) {
      print('WhisperPlatform: Transcribe error: $e');
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
      print('WhisperPlatform: Released');
    } catch (e) {
      print('WhisperPlatform: Release error: $e');
    }
  }
  
  static bool get isAvailable => _isInitialized;
  
  /// Reset state (for testing or reinit)
  static void reset() {
    _isInitialized = false;
    _modelPath = null;
  }
}