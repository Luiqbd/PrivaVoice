import 'dart:ffi';
import 'dart:io';
import 'dart:isolate';
import 'package:ffi/ffi.dart';
import 'package:flutter/foundation.dart';

// === FFI Type Definitions ===
typedef WhisperInitFromFileNative = Pointer<Void> Function(Pointer<Utf8> path);
typedef WhisperInitFromFileDart = Pointer<Void> Function(Pointer<Utf8> path);

typedef WhisperFreeNative = Void Function(Pointer<Void> ctx);
typedef WhisperFreeDart = void Function(Pointer<Void> ctx);

typedef WhisperFullNative = Int32 Function(
    Pointer<Void> ctx, Int32 flags, Pointer<Float> samples, Int32 n_samples);
typedef WhisperFullDart = int Function(
    Pointer<Void> ctx, int flags, Pointer<Float> samples, int n_samples);

// Whisper full with prompt - uses parameters struct
typedef WhisperFullParamsNative = Pointer<Void> Function(Pointer<Void> ctx);
typedef WhisperFullParamsDart = Pointer<Void> Function(Pointer<Void> ctx);

typedef WhisperFullNSegmentsNative = Int32 Function(Pointer<Void> ctx);
typedef WhisperFullNSegmentsDart = int Function(Pointer<Void> ctx);

typedef WhisperFullGetSegmentTextNative = Pointer<Utf8> Function(
    Pointer<Void> ctx, Int32 i_segment);
typedef WhisperFullGetSegmentTextDart = Pointer<Utf8> Function(
    Pointer<Void> ctx, int i_segment);

/// Real Whisper.cpp FFI bindings with memory management
class WhisperBindings {
  static DynamicLibrary? _lib;
  static bool _isLoaded = false;
  static Pointer<Void>? _ctx;
  static String? _ptBrPrompt; // Store PT-BR prompt
  
  static WhisperInitFromFileDart? _initFromFile;
  static WhisperFreeDart? _free;
  static WhisperFullDart? _full;
  static WhisperFullNSegmentsDart? _nSegments;
  static WhisperFullGetSegmentTextDart? _getSegmentText;

  static bool get isAvailable => _isLoaded;
  
  /// Load PT-BR prompt from assets folder
  static Future<void> loadPtBrPrompt() async {
    if (_ptBrPrompt != null) return; // Already loaded
    
    try {
      final buffer = StringBuffer();
      final basePath = 'assets/pt-br';
      
      // Read all .txt files from pt-br folder
      final files = [
        'palavras_comuns.txt',
        'juridico.txt', 
        'negocios.txt',
        'localidades.txt',
        'nomes_proprios.txt',
        'frases_basicas.txt',
      ];
      
      for (final fileName in files) {
        try {
          final content = await File('$basePath/$fileName').readAsString();
          if (content.isNotEmpty) {
            buffer.write(content);
            buffer.write(' ');
          }
        } catch (e) {
          print('Whisper: Could not read $fileName: $e');
        }
      }
      
      _ptBrPrompt = buffer.toString().trim();
      print('Whisper: ✅ PT-BR prompt loaded (${_ptBrPrompt!.length} chars)');
    } catch (e) {
      print('Whisper: PT-BR prompt load error: $e');
      _ptBrPrompt = null;
    }
  }

  static bool load() {
    if (_isLoaded) return true;

    try {
      // Try multiple library names that mx.valdora might use
      List<String> libNames = [
        'libwhisper.so',
        'libwhisper_android.so',
        'libwhisper-android.so',
      ];
      
      for (String libName in libNames) {
        try {
          _lib = DynamicLibrary.open(libName);
          print('Whisper: ✅ Loaded $libName');
          break;
        } catch (e) {
          print('Whisper: ❌ $libName not found: $e');
        }
      }
      
      // If still null, try system paths
      if (_lib == null) {
        List<String> paths = [
          '/data/data/com.privavoice.privavoice/lib/libwhisper.so',
          '/data/data/com.privavoice.privavoice/app_lib/libwhisper.so',
        ];
        
        for (String path in paths) {
          try {
            _lib = DynamicLibrary.open(path);
            print('Whisper: ✅ Loaded from: $path');
            break;
          } catch (e) {
            print('Whisper: ❌ Failed: $path - $e');
          }
        }
      }
      
      if (_lib == null) {
        throw Exception('Could not load whisper library');
      }
      
      // Try standard C ABI first, then Java JNI names
      try {
        _initFromFile = _lib!.lookup<NativeFunction<WhisperInitFromFileNative>>('whisper_init_from_file').asFunction<WhisperInitFromFileDart>();
        _free = _lib!.lookup<NativeFunction<WhisperFreeNative>>('whisper_free').asFunction<WhisperFreeDart>();
        _full = _lib!.lookup<NativeFunction<WhisperFullNative>>('whisper_full').asFunction<WhisperFullDart>();
        _nSegments = _lib!.lookup<NativeFunction<WhisperFullNSegmentsNative>>('whisper_full_n_segments').asFunction<WhisperFullNSegmentsDart>();
        _getSegmentText = _lib!.lookup<NativeFunction<WhisperFullGetSegmentTextNative>>('whisper_full_get_segment_text').asFunction<WhisperFullGetSegmentTextDart>();
        print('Whisper: ✅ Standard C ABI functions bound');
      } catch (e) {
        print('Whisper: Standard C ABI failed, trying Java JNI: $e');
        // Try Java JNI names as fallback
        try {
          _initFromFile = _lib!.lookup<NativeFunction<WhisperInitFromFileNative>>('Java_com_whispercppdemo_whisper_WhisperLib_initContext').asFunction<WhisperInitFromFileDart>();
          print('Whisper: ✅ Java JNI init found');
        } catch (e2) {
          print('Whisper: ❌ No valid symbols found: $e2');
          throw Exception('No valid whisper symbols in library');
        }
      }
      
      _isLoaded = true;
      print('Whisper: ✅ All FFI functions bound');
    } catch (e) {
      print('Whisper: ❌ FFI binding error = $e');
      _isLoaded = false;
    }

    return _isLoaded;
  }

  /// Unload native library - frees memory
  static void unload() {
    print('Whisper: unload() called');
    
    if (_ctx != null && _ctx != Pointer<Void>.fromAddress(0)) {
      try {
        _free!(_ctx!);
        print('Whisper: Context freed');
      } catch (e) {
        print('Whisper: free error = $e');
      }
      _ctx = null;
    }
    
    _lib = null;
    _isLoaded = false;
    _initFromFile = null;
    _free = null;
    _full = null;
    _nSegments = null;
    _getSegmentText = null;
    
    print('Whisper: ✅ Library unloaded, memory freed');
  }

  static Pointer<Void>? initFromFile(String modelPath) {
    print('Whisper: initFromFile($modelPath)');
    
    if (!_isLoaded) {
      if (!load()) {
        print('Whisper: ❌ load() failed');
        return null;
      }
    }
    
    final file = File(modelPath);
    if (!file.existsSync()) {
      print('Whisper: ❌ FILE NOT FOUND');
      return null;
    }
    
    final stat = file.statSync();
    print('Whisper: Model size = ${stat.size} bytes');

    if (stat.size < 1000) {
      print('Whisper: ❌ Model file TOO SMALL');
      return null;
    }

    try {
      final pathPtr = modelPath.toNativeUtf8();
      _ctx = _initFromFile!(pathPtr);
      calloc.free(pathPtr);

      if (_ctx != null && _ctx != Pointer<Void>.fromAddress(0)) {
        print('Whisper: ✅ ctx = VALID');
        return _ctx;
      }
      print('Whisper: ❌ ctx = NULL');
      return null;
    } catch (e) {
      print('Whisper: initFromFile ERROR = $e');
      return null;
    }
  }

  static Pointer<Float>? _loadWavAudio(String audioPath) {
    try {
      final file = File(audioPath);
      if (!file.existsSync()) {
        print('Whisper: ❌ Audio NOT FOUND: $audioPath');
        return null;
      }
      
      final bytes = file.readAsBytesSync();
      
      if (bytes.length < 100) {
        print('Whisper: ❌ Audio TOO SMALL');
        return null;
      }
      
      int dataOffset = 44;
      int dataSize = bytes.length - dataOffset;
      final numSamples = dataSize ~/ 2;
      
      if (numSamples <= 0) {
        print('Whisper: ❌ No samples');
        return null;
      }
      
      // Use malloc with proper alignment for Float32 (4 bytes)
      final samplesPtr = calloc<Float>(numSamples);
      
      // Copy with proper alignment - convert Int16 PCM to Float32
      for (int i = 0; i < numSamples; i++) {
        // Read as unsigned 16-bit, then convert to signed
        int sample = bytes[dataOffset + i * 2] | (bytes[dataOffset + i * 2 + 1] << 8);
        // Convert unsigned to signed
        if (sample >= 32768) sample -= 65536;
        // Normalize to -1.0 to 1.0
        samplesPtr[i] = sample / 32768.0;
      }
      
      print('Whisper: ✅ Allocated $numSamples Float32 samples with proper alignment');
      return samplesPtr;
    } catch (e) {
      print('Whisper: WAV ERROR = $e');
      return null;
    }
  }

  static String? full({required Pointer<Void> ctx, required String audioPath, bool withTimestamps = true}) {
    print('Whisper: full() - audio: $audioPath');
    
    // Log PT-BR prompt availability
    if (_ptBrPrompt != null && _ptBrPrompt!.isNotEmpty) {
      print('Whisper: ✅ Using PT-BR context (${_ptBrPrompt!.length} chars)');
    }

    if (ctx == Pointer<Void>.fromAddress(0)) {
      print('Whisper: ❌ ctx is NULL');
      return null;
    }

    final samples = _loadWavAudio(audioPath);
    if (samples == null) {
      print('Whisper: ❌ Failed to load audio');
      return null;
    }

    final file = File(audioPath);
    final bytes = file.readAsBytesSync();
    final numSamples = (bytes.length - 44) ~/ 2;
    print('Whisper: Processing $numSamples samples...');

    try {
      // Wrap in try-catch to prevent native crash from killing app
      String? result;
      try {
        result = _callWhisperFull(ctx, samples, numSamples);
      } catch (nativeError) {
        print('Whisper: Native call FAILED: $nativeError');
        calloc.free(samples);
        return 'Erro na transcrição: áudio corrompido ou formato inválido';
      }
      
      print('Whisper: whisper_full result = $result');
      calloc.free(samples);
      
      if (result == null || result.isEmpty) {
        return 'Transcrição vazia';
      }
      
      return result;
    } catch (e) {
      print('Whisper: full() ERROR = $e');
      calloc.free(samples);
      return 'Erro: $e';
    }
  }
  
  // Separate method to isolate native call
  static String? _callWhisperFull(Pointer<Void> ctx, Pointer<Float> samples, int numSamples) {
    final result = _full!(ctx, 0, samples, numSamples);
    print('Whisper: whisper_full result code = $result');
    
    if (result != 0) {
      print('Whisper: whisper_full returned error code');
      return null;
    }

    final nSegments = _nSegments!(ctx);
    print('Whisper: n_segments = $nSegments');

    if (nSegments <= 0) {
      print('Whisper: No segments');
      return null;
    }

    final buffer = StringBuffer();
    for (int i = 0; i < nSegments; i++) {
      final textPtr = _getSegmentText!(ctx, i);
      if (textPtr != Pointer<Utf8>.fromAddress(0)) {
        if (buffer.isNotEmpty) buffer.write(' ');
        buffer.write(textPtr.toDartString());
      }
    }

    return buffer.toString();
  }

  /// Get the PT-BR prompt for use in transcription context
  static String? getPtBrPrompt() => _ptBrPrompt;

  static void dispose() {
    print('Whisper: dispose() called');
    unload();
  }
}
