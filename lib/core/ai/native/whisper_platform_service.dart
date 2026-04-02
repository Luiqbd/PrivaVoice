import 'dart:io';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

/// Platform channel wrapper for mx.valdora whisper-android library
/// This provides 100% offline transcription without external APIs
class WhisperPlatformService {
  static const _channel = MethodChannel('com.privavoice/whisper');
  
  static bool _isInitialized = false;
  static String? _modelPath;
  
  /// Initialize the whisper context with model file
  static Future<bool> initialize(String modelPath) async {
    if (_isInitialized) return true;
    
    try {
      _modelPath = modelPath;
      
      // Check if model file exists
      final file = File(modelPath);
      if (!await file.exists()) {
        print('WhisperPlatform: Model file not found: $modelPath');
        return false;
      }
      
      // Initialize via platform channel
      final result = await _channel.invokeMethod<bool>('init', {
        'modelPath': modelPath,
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
  static Future<String?> transcribe(String audioPath) async {
    if (!_isInitialized) {
      print('WhisperPlatform: Not initialized');
      return null;
    }
    
    try {
      // Check audio file exists
      final audioFile = File(audioPath);
      if (!await audioFile.exists()) {
        print('WhisperPlatform: Audio file not found: $audioPath');
        return null;
      }
      
      // Transcribe via platform channel
      final result = await _channel.invokeMethod<String>('transcribe', {
        'audioPath': audioPath,
      });
      
      print('WhisperPlatform: Transcribe result: ${result?.substring(0, 50) ?? "null"}...');
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
  
  /// Check if available
  static bool get isAvailable => _isInitialized;
}