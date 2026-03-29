import 'dart:ffi';
import 'dart:io';
import 'package:ffi/ffi.dart';

class WhisperBindings {
  static DynamicLibrary? _lib;
  static bool _isLoaded = false;

  static bool get isAvailable => _isLoaded;

  static bool load() {
    if (_isLoaded) return true;
    try {
      if (Platform.isAndroid) {
        _lib = DynamicLibrary.open('libwhisper.so');
      } else if (Platform.isLinux) {
        _lib = DynamicLibrary.open('libwhisper.so');
      } else if (Platform.isMacOS) {
        _lib = DynamicLibrary.open('libwhisper.dylib');
      }
      _isLoaded = _lib != null;
      print('Whisper: $_isLoaded');
    } catch (e) {
      print('Whisper load error: $e');
    }
    return _isLoaded;
  }

  static void dispose() {
    _lib = null;
    _isLoaded = false;
  }
}
