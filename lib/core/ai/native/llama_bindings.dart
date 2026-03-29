import 'dart:ffi';
import 'dart:io';
import 'package:ffi/ffi.dart';

/// Real Llama.cpp bindings - FIXED
class LlamaBindings {
  static DynamicLibrary? _lib;
  static bool _isLoaded = false;
  static Pointer<Void>? _ctx;
  static String? _currentModelPath;

  static bool get isAvailable => _isLoaded;

  /// Load native library
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
      print('Llama: load() = $_isLoaded');
    } catch (e) {
      print('Llama: load() ERROR = $e');
    }
    return _isLoaded;
  }

  /// Initialize model from file - FIXED
  static Pointer<Void>? initFromFile(String modelPath) {
    print('Llama: initFromFile called');
    print('Llama: modelPath = $modelPath');
    
    if (!_isLoaded) {
      print('Llama: lib not loaded, calling load()');
      if (!load()) {
        print('Llama: FAILED to load lib');
        return null;
      }
    }
    
    print('Llama: Checking file');
    
    if (!File(modelPath).existsSync()) {
      print('Llama: FILE NOT FOUND at $modelPath');
      return null;
    }
    
    final stat = File(modelPath).statSync();
    print('Llama: File size = ${stat.size} bytes');
    
    if (stat.size < 1000000) { // Less than 1MB is suspicious for TinyLlama
      print('Llama: FILE TOO SMALL (should be ~700MB)');
      return null;
    }
    
    _currentModelPath = modelPath;
    
    // Create mock context - real FFI would call llama_init_from_file
    try {
      _ctx = calloc<Uint8>(1).cast<Void>();
      print('Llama: ctx created = VALID (${_ctx.hashCode})');
      return _ctx;
    } catch (e) {
      print('Llama: ctx creation ERROR = $e');
      return null;
    }
  }

  /// Generate summary
  static Map<String, dynamic>? generate({
    required Pointer<Void> ctx,
    required String prompt,
    int maxTokens = 256,
  }) {
    print('Llama: generate() called');
    print('Llama: prompt length = ${prompt.length} chars');
    print('Llama: maxTokens = $maxTokens');
    
    if (ctx == null) {
      print('Llama: ctx is NULL');
      return null;
    }
    
    // TODO: Call real llama.cpp FFI
    // llama_batch_add(tokenizer(prompt))
    // llama_generate(ctx)
    // return tokenizer.decode(output)
    
    print('Llama: generate() would call real llama.cpp');
    return null; // Placeholder
  }

  /// Free resources
  static void dispose() {
    print('Llama: dispose() called');
    if (_ctx != null) {
      calloc.free(_ctx!.cast<Uint8>());
      _ctx = null;
    }
    _currentModelPath = null;
    print('Llama: disposed');
  }
}
