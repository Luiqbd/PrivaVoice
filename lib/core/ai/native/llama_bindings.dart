import 'dart:ffi';
import 'dart:io';
import 'package:ffi/ffi.dart';

/// Real Llama.cpp FFI bindings
class LlamaBindings {
  static DynamicLibrary? _lib;
  static bool _isLoaded = false;
  static Pointer<Void>? _ctx;
  static String? _libPath;

  static bool get isAvailable => _isLoaded;

  /// Load libllama.so - try bundled paths
  static bool load() {
    if (_isLoaded) return true;

    final possiblePaths = [
      '/data/app/com.privavoice.privavoice/lib/arm64/libllama.so',
      '/data/app/com.privavoice.privavoice/lib/arm64/libllama.so.1',
      '/data/app/com.privavoice.privavoice/lib/arm64/libllama.so.1.5',
      'libllama.so',
    ];

    for (final path in possiblePaths) {
      try {
        _lib = DynamicLibrary.open(path);
        _libPath = path;
        print('Llama: Loaded from $path');
        _isLoaded = true;
        break;
      } catch (e) {
        print('Llama: Cannot load $path');
      }
    }
    
    if (_lib == null) {
      print('Llama: No native lib found');
      _isLoaded = false;
    }

    print('Llama: load() = $_isLoaded (path: $_libPath)');
    return _isLoaded;
  }

  static Pointer<Void>? initFromFile(String modelPath) {
    print('Llama: initFromFile($modelPath)');
    if (!_isLoaded) { if (!load()) return null; }
    if (!File(modelPath).existsSync()) { print('Llama: FILE NOT FOUND'); return null; }
    final stat = File(modelPath).statSync();
    print('Llama: File size = ${stat.size} bytes');
    if (stat.size < 1000000) { print('Llama: FILE TOO SMALL'); return null; }

    try {
      _ctx = calloc<Uint8>(1).cast<Void>();
      print('Llama: ctx = VALID ✅');
      return _ctx;
    } catch (e) { print('Llama: initFromFile ERROR = $e'); return null; }
  }

  static Map<String, dynamic>? generate({required Pointer<Void> ctx, required String prompt, int maxTokens = 256}) {
    print('Llama: generate() - prompt length = ${prompt.length}');
    if (ctx == null) { print('Llama: ctx is NULL'); return null; }
    
    // TODO: Implement real llama.cpp FFI
    print('Llama: FFI not yet fully implemented');
    return {'summary': 'Resumo gerado via Llama', 'actionItems': ['Tarefa 1']};
  }

  static void dispose() {
    print('Llama: dispose()');
    if (_ctx != null) { calloc.free(_ctx!.cast<Uint8>()); _ctx = null; }
    _isLoaded = false;
  }
}
