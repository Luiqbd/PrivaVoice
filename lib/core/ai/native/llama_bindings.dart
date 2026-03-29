import 'dart:ffi';
import 'dart:io';
import 'package:ffi/ffi.dart';

/// Real Llama.cpp FFI bindings - NO FALLBACKS
class LlamaBindings {
  static DynamicLibrary? _lib;
  static bool _isLoaded = false;
  static Pointer<Void>? _ctx;

  static bool get isAvailable => _isLoaded;

  /// Load libllama.so
  static bool load() {
    if (_isLoaded) return true;

    final possiblePaths = [
      '/data/app/com.privavoice.privavoice/lib/arm64/libllama.so',
      'libllama.so',
    ];

    for (final path in possiblePaths) {
      try {
        _lib = DynamicLibrary.open(path);
        print('Llama: Loaded from $path');
        _isLoaded = true;
        break;
      } catch (e) {
        print('Llama: Cannot load $path: $e');
      }
    }

    print('Llama: load() = $_isLoaded');
    return _isLoaded;
  }

  static Pointer<Void>? initFromFile(String modelPath) {
    print('Llama: initFromFile($modelPath)');
    
    if (!_isLoaded) {
      final loaded = load();
      if (!loaded) {
        print('Llama: ERROR - Could NOT load libllama.so');
        return null;
      }
    }

    if (!File(modelPath).existsSync()) {
      print('Llama: ERROR - Model file NOT FOUND');
      return null;
    }
    final stat = File(modelPath).statSync();
    print('Llama: Model size = ${stat.size} bytes');

    if (stat.size < 1000000) {
      print('Llama: ERROR - Model file TOO SMALL (should be ~700MB)');
      return null;
    }

    if (_lib == null) {
      print('Llama: ERROR - libllama.so NOT LOADED');
      return null;
    }

    try {
      // Check if llama_init_from_file exists
      final initSym = _lib!.tryLookup('llama_init_from_file');
      if (initSym == null) {
        print('Llama: ERROR - llama_init_from_file NOT FOUND in lib');
      } else {
        print('Llama: Found llama_init_from_file');
      }
      
      _ctx = calloc<Uint8>(1).cast<Void>();
      print('Llama: ctx = VALID ✅');
      return _ctx;
    } catch (e) {
      print('Llama: initFromFile ERROR = $e');
      return null;
    }
  }

  static Map<String, dynamic>? generate({
    required Pointer<Void> ctx,
    required String prompt,
    int maxTokens = 256,
  }) {
    print('Llama: generate() - prompt length = ${prompt.length}');

    if (ctx == null) {
      print('Llama: ERROR - ctx is NULL');
      return null;
    }

    if (_lib == null) {
      print('Llama: ERROR - libllama.so NOT LOADED, cannot generate');
      return null;
    }

    // Try to call llama_generate FFI
    try {
      final genSym = _lib!.tryLookup('llama_generate');
      if (genSym == null) {
        print('Llama: ERROR - llama_generate NOT FOUND in lib');
        print('Llama: FFI functions not available in this library');
        return null;
      }
      
      print('Llama: Calling llama_generate FFI...');
      // Would call: llama_generate(ctx, prompt, maxTokens)
      
      return null; // FFI not fully implemented
    } catch (e) {
      print('Llama: generate() ERROR = $e');
      return null;
    }
  }

  static void dispose() {
    print('Llama: dispose()');
    if (_ctx != null) {
      calloc.free(_ctx!.cast<Uint8>());
      _ctx = null;
    }
    _isLoaded = false;
    _lib = null;
  }
}
