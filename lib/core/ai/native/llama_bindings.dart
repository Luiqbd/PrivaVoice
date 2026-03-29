import 'dart:ffi';
import 'dart:io';
import 'package:ffi/ffi.dart';

class LlamaBindings {
  static DynamicLibrary? _lib;
  static bool _isLoaded = false;

  static bool get isAvailable => _isLoaded;

  static bool load() {
    if (_isLoaded) return true;
    try {
      if (Platform.isAndroid) {
        _lib = DynamicLibrary.open('libllama.so');
      } else if (Platform.isLinux) {
        _lib = DynamicLibrary.open('libllama.so');
      } else if (Platform.isMacOS) {
        _lib = DynamicLibrary.open('libllama.dylib');
      }
      _isLoaded = _lib != null;
      print('Llama: $_isLoaded');
    } catch (e) {
      print('Llama load error: $e');
    }
    return _isLoaded;
  }

  static void dispose() {
    _lib = null;
    _isLoaded = false;
  }
}
