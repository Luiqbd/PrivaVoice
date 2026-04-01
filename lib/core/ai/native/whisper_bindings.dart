import 'dart:ffi';
import 'dart:io';
import 'package:ffi/ffi.dart';

// === FFI Type Definitions ===
typedef WhisperInitFromFileNative = Pointer<Void> Function(Pointer<Utf8> path);
typedef WhisperInitFromFileDart = Pointer<Void> Function(Pointer<Utf8> path);

typedef WhisperFreeNative = Void Function(Pointer<Void> ctx);
typedef WhisperFreeDart = void Function(Pointer<Void> ctx);

typedef WhisperFullNative = Int32 Function(
    Pointer<Void> ctx, Int32 flags, Pointer<Float> samples, Int32 n_samples);
typedef WhisperFullDart = int Function(
    Pointer<Void> ctx, int flags, Pointer<Float> samples, int n_samples);

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
  
  static WhisperInitFromFileDart? _initFromFile;
  static WhisperFreeDart? _free;
  static WhisperFullDart? _full;
  static WhisperFullNSegmentsDart? _nSegments;
  static WhisperFullGetSegmentTextDart? _getSegmentText;

  static bool get isAvailable => _isLoaded;

  static bool load() {
    if (_isLoaded) return true;

    try {
      // First try to use System.loadLibrary via platform channel
      // This works with AAR dependencies that include .so files
      try {
        _lib = DynamicLibrary.open('libwhisper.so');
        print('Whisper: ✅ Loaded libwhisper.so directly');
      } catch (e) {
        print('Whisper: Direct open failed: $e');
        // Try alternative paths for when AAR .so is loaded via System.loadLibrary
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
        throw Exception('Could not load libwhisper.so from any path');
      }
      
      _initFromFile = _lib!.lookup<NativeFunction<WhisperInitFromFileNative>>('whisper_init_from_file').asFunction<WhisperInitFromFileDart>();
      _free = _lib!.lookup<NativeFunction<WhisperFreeNative>>('whisper_free').asFunction<WhisperFreeDart>();
      _full = _lib!.lookup<NativeFunction<WhisperFullNative>>('whisper_full').asFunction<WhisperFullDart>();
      _nSegments = _lib!.lookup<NativeFunction<WhisperFullNSegmentsNative>>('whisper_full_n_segments').asFunction<WhisperFullNSegmentsDart>();
      _getSegmentText = _lib!.lookup<NativeFunction<WhisperFullGetSegmentTextNative>>('whisper_full_get_segment_text').asFunction<WhisperFullGetSegmentTextDart>();
      
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
      
      final samplesPtr = calloc<Float>(numSamples);
      for (int i = 0; i < numSamples; i++) {
        int sample = bytes[dataOffset + i * 2] | (bytes[dataOffset + i * 2 + 1] << 8);
        if (sample >= 32768) sample -= 65536;
        samplesPtr[i] = sample / 32768.0;
      }
      
      print('Whisper: Converted $numSamples samples to Float32');
      return samplesPtr;
    } catch (e) {
      print('Whisper: WAV ERROR = $e');
      return null;
    }
  }

  static String? full({required Pointer<Void> ctx, required String audioPath, bool withTimestamps = true}) {
    print('Whisper: full() - audio: $audioPath');

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
      final result = _full!(ctx, 0, samples, numSamples);
      print('Whisper: whisper_full result = $result');
      calloc.free(samples);

      if (result != 0) {
        print('Whisper: ❌ whisper_full FAILED');
        return null;
      }

      final nSegments = _nSegments!(ctx);
      print('Whisper: n_segments = $nSegments');

      if (nSegments <= 0) {
        print('Whisper: ❌ No segments');
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
    } catch (e) {
      print('Whisper: full() ERROR = $e');
      calloc.free(samples);
      return null;
    }
  }

  static List<Map<String, dynamic>>? getWordTimestamps(Pointer<Void> ctx) {
    return [];
  }

  static void dispose() {
    print('Whisper: dispose() called');
    unload();
  }
}
