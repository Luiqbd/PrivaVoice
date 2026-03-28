import 'dart:ffi';
import 'dart:io';
import 'package:ffi/ffi.dart';

/// Native function bindings for Llama.cpp
/// Loads libllama.so at runtime for LLM inference
class LlamaBindings {
  static DynamicLibrary? _lib;
  static bool _isLoaded = false;

  // Function typedefs
  static Function? _llama_init_from_file;
  static Function? _llama_free;
  static Function? _llama_load_model_from_file;
  static Function? _llama_free_model;
  static Function? _llama_new_context_with_model;
  static Function? _llama_free_context;
  static Function? _llama_decode;
  static Function? _llama_token_nl;
  static Function? _llama_token_eos;
  static Function? _llama_token_bos;
  static Function? _llama_token_eos;
  static Function? _llama_eval;
  static Function? _llama_get_token_text;
  static Function? _llama_token_get_text;
  static Function? _llama_sample_token;
  static Function? _llama_sampling_free;

  /// Check if native library is available
  static bool get isAvailable => _isLoaded;

  /// Load the native library
  static bool load() {
    if (_isLoaded) return true;

    try {
      if (Platform.isAndroid) {
        _lib = DynamicLibrary.open('libllama.so');
      } else if (Platform.isLinux) {
        _lib = DynamicLibrary.open('libllama.so');
      } else if (Platform.isMacOS) {
        _lib = DynamicLibrary.open('libllama.dylib');
      } else if (Platform.isWindows) {
        _lib = DynamicLibrary.open('libllama.dll');
      }

      if (_lib != null) {
        _bindFunctions();
        _isLoaded = true;
        print('Llama native library loaded successfully');
        return true;
      }
    } catch (e) {
      print('Failed to load Llama library: $e');
    }

    return false;
  }

  static void _bindFunctions() {
    if (_lib == null) return;

    // Bind Llama functions
    _llama_init_from_file = _lib!.lookupFunction<
        Pointer<Void> Function(Pointer<Utf8>),
        Pointer<Void> Function(Pointer<Utf8>)>('llama_init_from_file');

    _llama_free = _lib!.lookupFunction<
        Void Function(Pointer<Void>),
        void Function(Pointer<Void>)>('llama_free');

    _llama_load_model_from_file = _lib!.lookupFunction<
        Pointer<Void> Function(Pointer<Utf8>, Pointer<Void>),
        Pointer<Void> Function(Pointer<Utf8>, Pointer<Void>)>('llama_load_model_from_file');

    _llama_free_model = _lib!.lookupFunction<
        Void Function(Pointer<Void>),
        void Function(Pointer<Void>)>('llama_free_model');

    _llama_new_context_with_model = _lib!.lookupFunction<
        Pointer<Void> Function(Pointer<Void>, Pointer<Void>),
        Pointer<Void> Function(Pointer<Void>, Pointer<Void>)>('llama_new_context_with_model');

    _llama_free_context = _lib!.lookupFunction<
        Void Function(Pointer<Void>),
        void Function(Pointer<Void>)>('llama_free_context');

    _llama_decode = _lib!.lookupFunction<
        Int32 Function(Pointer<Void>, Pointer<Void>, Int32),
        int Function(Pointer<Void>, Pointer<Void>, int)>('llama_decode');

    _llama_eval = _lib!.lookupFunction<
        Int32 Function(Pointer<Void>, Pointer<Void>, Int32),
        int Function(Pointer<Void>, Pointer<Void>, int)>('llama_eval');

    _llama_sampling_free = _lib!.lookupFunction<
        Void Function(Pointer<Void>),
        void Function(Pointer<Void>)>('llama_sampling_free');
  }

  /// Load model from GGUF file
  static Pointer<Void>? loadModelFromFile(String modelPath) {
    if (!_isLoaded) {
      if (!load()) return null;
    }

    final pathPtr = modelPath.toNativeUtf8();
    try {
      // Note: In production, we'd set up params properly
      final model = _llama_load_model_from_file!(pathPtr, nullptr);
      return model;
    } finally {
      calloc.free(pathPtr);
    }
  }

  /// Create new context from model
  static Pointer<Void>? newContext(Pointer<Void> model) {
    if (_llama_new_context_with_model != null) {
      return _llama_new_context_with_model!(model, nullptr);
    }
    return null;
  }

  /// Evaluate tokens
  static int eval(Pointer<Void> ctx, Pointer<Void> tokens, int nTokens) {
    if (_llama_eval != null) {
      return _llama_eval!(ctx, tokens, nTokens);
    }
    return -1;
  }

  /// Free model resources
  static void freeModel(Pointer<Void> model) {
    if (_llama_free_model != null && model != nullptr) {
      _llama_free_model!(model);
    }
  }

  /// Free context
  static void freeContext(Pointer<Void> ctx) {
    if (_llama_free_context != null && ctx != nullptr) {
      _llama_free_context!(ctx);
    }
  }

  /// Free all resources
  static void dispose() {
    _lib = null;
    _isLoaded = false;
  }
}