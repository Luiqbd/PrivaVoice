import 'dart:ffi';
import 'dart:io';
import 'dart:typed_data';
import 'package:ffi/ffi.dart';

// === FFI Type Definitions ===
typedef WhisperInitFromFileNative = Pointer<Void> Function(Pointer<Utf8> path);
typedef WhisperInitFromFileDart = Pointer<Void> Function(Pointer<Utf8> path);

typedef WhisperFreeNative = Void Function(Pointer<Void> ctx);
typedef WhisperFreeDart = void Function(Pointer<Void> ctx);

typedef WhisperFullNative = Int32 Function(
    Pointer<Void> ctx,
    Int32 flags,
    Pointer<Float> samples,
    Int32 n_samples);
typedef WhisperFullDart = int Function(
    Pointer<Void> ctx,
    int flags,
    Pointer<Float> samples,
    int n_samples);

typedef WhisperFullNSegmentsNative = Int32 Function(Pointer<Void> ctx);
typedef WhisperFullNSegmentsDart = int Function(Pointer<Void> ctx);

typedef WhisperFullGetSegmentTextNative = Pointer<Utf8> Function(
    Pointer<Void> ctx, Int32 i_segment);
typedef WhisperFullGetSegmentTextDart = Pointer<Utf8> Function(
    Pointer<Void> ctx, int i_segment);

/// Real Whisper.cpp FFI bindings
class WhisperBindings {
  static DynamicLibrary? _lib;
  static bool _isLoaded = false;
  static Pointer<Void>? _ctx;
  
  // FFI functions
  static WhisperInitFromFileDart? _initFromFile;
  static WhisperFreeDart? _free;
  static WhisperFullDart? _full;
  static WhisperFullNSegmentsDart? _nSegments;
  static WhisperFullGetSegmentTextDart? _getSegmentText;

  static bool get isAvailable => _isLoaded;

  /// Load libwhisper.so
  static bool load() {
    if (_isLoaded) return true;

    try {
      _lib = DynamicLibrary.open('libwhisper.so');
      print('Whisper: ✅ libwhisper.so loaded');
      
      // Bind FFI functions
      _initFromFile = _lib!
          .lookup<NativeFunction<WhisperInitFromFileNative>>('whisper_init_from_file')
          .asFunction<WhisperInitFromFileDart>();
          
      _free = _lib!
          .lookup<NativeFunction<WhisperFreeNative>>('whisper_free')
          .asFunction<WhisperFreeDart>();
          
      _full = _lib!
          .lookup<NativeFunction<WhisperFullNative>>('whisper_full')
          .asFunction<WhisperFullDart>();
          
      _nSegments = _lib!
          .lookup<NativeFunction<WhisperFullNSegmentsNative>>('whisper_full_n_segments')
          .asFunction<WhisperFullNSegmentsDart>();
          
      _getSegmentText = _lib!
          .lookup<NativeFunction<WhisperFullGetSegmentTextNative>>('whisper_full_get_segment_text')
          .asFunction<WhisperFullGetSegmentTextDart>();
      
      _isLoaded = true;
      print('Whisper: ✅ All FFI functions bound');
    } catch (e) {
      print('Whisper: ❌ FFI binding error = $e');
    }

    print('Whisper: load() = $_isLoaded');
    return _isLoaded;
  }

  static Pointer<Void>? initFromFile(String modelPath) {
    print('Whisper: initFromFile($modelPath)');
    
    if (!_isLoaded) {
      if (!load()) {
        print('Whisper: ❌ load() failed');
        return null;
      }
    }
    
    if (!File(modelPath).existsSync()) {
      print('Whisper: ❌ Model file NOT FOUND');
      return null;
    }
    
    final stat = File(modelPath).statSync();
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

  /// Load WAV and convert to Float32 PCM
  static Pointer<Float>? _loadWavAudio(String audioPath) {
    try {
      final file = File(audioPath);
      if (!file.existsSync()) {
        print('Whisper: ❌ Audio file NOT FOUND');
        return null;
      }
      
      final bytes = file.readAsBytesSync();
      print('Whisper: Audio bytes = ${bytes.length}');
      
      if (bytes.length < 100) {
        print('Whisper: ❌ Audio file TOO SMALL');
        return null;
      }
      
      // Skip 44-byte WAV header
      int dataOffset = 44;
      int dataSize = bytes.length - dataOffset;
      final numSamples = dataSize ~/ 2;
      
      if (numSamples <= 0) {
        print('Whisper: ❌ No samples extracted');
        return null;
      }
      
      // Convert 16-bit PCM to Float32
      final samplesPtr = calloc<Float>(numSamples);
      for (int i = 0; i < numSamples; i++) {
        int sample = bytes[dataOffset + i * 2] | (bytes[dataOffset + i * 2 + 1] << 8);
        if (sample >= 32768) sample -= 65536;
        // Convert to float (-1.0 to 1.0)
        samplesPtr[i] = sample / 32768.0;
      }
      
      print('Whisper: ✅ Converted $numSamples samples to Float32');
      return samplesPtr;
    } catch (e) {
      print('Whisper: WAV ERROR = $e');
      return null;
    }
  }

  /// Run full transcription - REAL FFI
  static String? full({
    required Pointer<Void> ctx,
    required String audioPath,
    bool withTimestamps = true,
  }) {
    print('Whisper: full() - audio: $audioPath');

    if (ctx == null) {
      print('Whisper: ❌ ctx is NULL');
      return null;
    }

    // Load and convert audio to Float32 PCM
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
      // Call whisper_full with Float32 samples
      final result = _full!(ctx, 0, samples, numSamples);
      print('Whisper: whisper_full result = $result');
      
      // Free samples memory
      calloc.free(samples);

      if (result != 0) {
        print('Whisper: ❌ whisper_full FAILED with code $result');
        return null;
      }

      // Get number of segments
      final nSegments = _nSegments!(ctx);
      print('Whisper: n_segments = $nSegments');

      if (nSegments <= 0) {
        print('Whisper: ❌ No segments returned');
        return null;
      }

      // Extract text from all segments
      final buffer = StringBuffer();
      for (int i = 0; i < nSegments; i++) {
        final textPtr = _getSegmentText!(ctx, i);
        if (textPtr != Pointer<Utf8>.fromAddress(0)) {
          final text = textPtr.toDartString();
          if (buffer.isNotEmpty) buffer.write(' ');
          buffer.write(text);
        }
      }

      final transcription = buffer.toString();
      print('Whisper: ✅ Transcription = "${transcription.substring(0, transcription.length > 100 ? 100 : transcription.length)}..."');
      
      return transcription;
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
    print('Whisper: dispose()');
    if (_ctx != null && _ctx != Pointer<Void>.fromAddress(0)) {
      try {
        _free!(_ctx!);
      } catch (e) {
        print('Whisper: free ERROR = $e');
      }
      _ctx = null;
    }
    _isLoaded = false;
    _lib = null;
  }
}
