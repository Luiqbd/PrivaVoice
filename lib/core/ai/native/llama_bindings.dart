import 'dart:ffi';
import 'dart:io';
import 'package:ffi/ffi.dart';

// === Llama.cpp FFI Type Definitions ===
typedef LlamaInitFromFileNative = Pointer<Void> Function(Pointer<Utf8> path);
typedef LlamaInitFromFileDart = Pointer<Void> Function(Pointer<Utf8> path);

typedef LlamaFreeNative = Void Function(Pointer<Void> ctx);
typedef LlamaFreeDart = void Function(Pointer<Void> ctx);

typedef LlamaDecodeNative = Int32 Function(Pointer<Void> ctx, Int32 n_tokens);
typedef LlamaDecodeDart = int Function(Pointer<Void> ctx, int n_tokens);

typedef LlamaTokenizeNative = Int32 Function(
    Pointer<Void> ctx,
    Pointer<Utf8> text,
    Pointer<Int32> tokens,
    Int32 n_max_tokens,
    Int32 add_bos);
typedef LlamaTokenizeDart = int Function(
    Pointer<Void> ctx,
    Pointer<Utf8> text,
    Pointer<Int32> tokens,
    int n_max_tokens,
    int add_bos);

typedef LlamaSampleTokenNative = Int32 Function(Pointer<Void> ctx);
typedef LlamaSampleTokenDart = int Function(Pointer<Void> ctx);

typedef LlamaTokenToStrNative = Pointer<Utf8> Function(Pointer<Void> ctx, Int32 token);
typedef LlamaTokenToStrDart = Pointer<Utf8> Function(Pointer<Void> ctx, int token);

/// Real Llama.cpp FFI bindings
class LlamaBindings {
  static DynamicLibrary? _lib;
  static bool _isLoaded = false;
  static Pointer<Void>? _ctx;
  
  // FFI functions
  static LlamaInitFromFileDart? _initFromFile;
  static LlamaFreeDart? _free;
  static LlamaTokenizeDart? _tokenize;
  static LlamaDecodeDart? _decode;
  static LlamaSampleTokenDart? _sampleToken;
  static LlamaTokenToStrDart? _tokenToStr;

  static bool get isAvailable => _isLoaded;

  /// Load libllama.so
  static bool load() {
    if (_isLoaded) return true;

    try {
      _lib = DynamicLibrary.open('libllama.so');
      
      if (_lib != null) {
        // Bind FFI functions
        _initFromFile = _lib!
            .lookup<NativeFunction<LlamaInitFromFileNative>>('llama_init_from_file')
            .asFunction<LlamaInitFromFileDart>();
            
        _free = _lib!
            .lookup<NativeFunction<LlamaFreeNative>>('llama_free')
            .asFunction<LlamaFreeDart>();
            
        _tokenize = _lib!
            .lookup<NativeFunction<LlamaTokenizeNative>>('llama_tokenize')
            .asFunction<LlamaTokenizeDart>();
            
        _decode = _lib!
            .lookup<NativeFunction<LlamaDecodeNative>>('llama_decode')
            .asFunction<LlamaDecodeDart>();
            
        _sampleToken = _lib!
            .lookup<NativeFunction<LlamaSampleTokenNative>>('llama_sample_token')
            .asFunction<LlamaSampleTokenDart>();
            
        _tokenToStr = _lib!
            .lookup<NativeFunction<LlamaTokenToStrNative>>('llama_token_to_str')
            .asFunction<LlamaTokenToStrDart>();
        
        _isLoaded = true;
        print('Llama: FFI functions bound successfully');
      }
    } catch (e) {
      print('Llama: FFI binding error = $e');
    }

    print('Llama: load() = $_isLoaded');
    return _isLoaded;
  }

  /// Initialize model from file - REAL llama_init_from_file
  static Pointer<Void>? initFromFile(String modelPath) {
    print('Llama: initFromFile($modelPath)');

    if (!_isLoaded) {
      if (!load()) return null;
    }

    if (!File(modelPath).existsSync()) {
      print('Llama: FILE NOT FOUND');
      return null;
    }

    final stat = File(modelPath).statSync();
    print('Llama: File size = ${stat.size} bytes');

    if (stat.size < 1000000) {
      print('Llama: FILE TOO SMALL (should be ~700MB)');
      return null;
    }

    try {
      final pathPtr = modelPath.toNativeUtf8();
      _ctx = _initFromFile!(pathPtr);
      calloc.free(pathPtr);

      if (_ctx != null && _ctx != Pointer<Void>.fromAddress(0)) {
        print('Llama: ctx = VALID ✅ (model loaded)');
        return _ctx;
      } else {
        print('Llama: ctx = NULL');
        return null;
      }
    } catch (e) {
      print('Llama: initFromFile ERROR = $e');
      return null;
    }
  }

  /// Generate summary - REAL llama inference
  static Map<String, dynamic>? generate({
    required Pointer<Void> ctx,
    required String prompt,
    int maxTokens = 256,
  }) {
    print('Llama: generate() - starting inference');

    if (ctx == null) {
      print('Llama: ctx is NULL');
      return null;
    }

    try {
      // Build prompt for summarization
      final fullPrompt = '''<s>[INST] Resuma o seguinte texto em português, identificando também possíveis tarefas/ações a serem tomadas:

${prompt}

Resumo e tarefas:[/INST]''';

      print('Llama: Tokenizing prompt (${fullPrompt.length} chars)...');
      
      // Tokenize
      final tokens = calloc<Int32>(1024);
      final nTokens = _tokenize!(ctx, fullPrompt.toNativeUtf8(), tokens, 1024, 1);
      
      if (nTokens <= 0) {
        print('Llama: Tokenization failed');
        calloc.free(tokens);
        return null;
      }
      
      print('Llama: Generated $nTokens tokens');
      
      // Decode tokens one by one
      final buffer = StringBuffer();
      for (int i = 0; i < maxTokens && i < nTokens; i++) {
        final result = _decode!(ctx, 1);
        if (result != 0) break;
        
        final token = _sampleToken!(ctx);
        if (token == 2) break; // </s> token
        
        final tokenStr = _tokenToStr!(ctx, token);
        if (tokenStr != Pointer<Utf8>.fromAddress(0)) {
          buffer.write(tokenStr.toDartString());
        }
      }
      
      calloc.free(tokens);
      
      final output = buffer.toString().trim();
      print('Llama: Generated ${output.length} chars');
      
      // Parse summary and action items
      final lines = output.split('\n');
      String summary = output;
      List<String> actionItems = [];
      
      // Simple extraction heuristic
      for (var line in lines) {
        if (line.toLowerCase().contains('tarefa') || 
            line.toLowerCase().contains('ação') ||
            line.toLowerCase().contains('action')) {
          actionItems.add(line);
        }
      }
      
      return {
        'summary': summary,
        'actionItems': actionItems,
      };
    } catch (e) {
      print('Llama: generate() ERROR = $e');
      return null;
    }
  }

  static void dispose() {
    print('Llama: dispose()');
    if (_ctx != null && _ctx != Pointer<Void>.fromAddress(0)) {
      try {
        _free!(_ctx!);
      } catch (e) {
        print('Llama: free ERROR = $e');
      }
      _ctx = null;
    }
    _isLoaded = false;
    print('Llama: disposed');
  }
}
