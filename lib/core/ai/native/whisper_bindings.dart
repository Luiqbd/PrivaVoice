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
    Pointer<Void> ctx, Int32 flags, Pointer<Float> samples, Int32 n_samples);
typedef WhisperFullDart = int Function(
    Pointer<Void> ctx, int flags, Pointer<Float> samples, int n_samples);

typedef WhisperFullNSegmentsNative = Int32 Function(Pointer<Void> ctx);
typedef WhisperFullNSegmentsDart = int Function(Pointer<Void> ctx);

typedef WhisperFullGetSegmentTextNative = Pointer<Utf8> Function(
    Pointer<Void> ctx, Int32 i_segment);
typedef WhisperFullGetSegmentTextDart = Pointer<Utf8> Function(
    Pointer<Void> ctx, int i_segment);

typedef WhisperFullGetSegmentTimestamp0Native = Int64 Function(
    Pointer<Void> ctx, Int32 i_segment);
typedef WhisperFullGetSegmentTimestamp0Dart = int Function(
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
  static WhisperFullGetSegmentTimestamp0Dart? _getSegmentTimestamp;

  static bool get isAvailable => _isLoaded;

  /// Load libwhisper.so
  static bool load() {
    if (_isLoaded) return true;

    try {
      _lib = DynamicLibrary.open('libwhisper.so');

      if (_lib != null) {
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
            
        _getSegmentTimestamp = _lib!
            .lookup<NativeFunction<WhisperFullGetSegmentTimestamp0Native>>('whisper_full_get_segment_t0')
            .asFunction<WhisperFullGetSegmentTimestamp0Dart>();
        
        _isLoaded = true;
        print('Whisper: FFI functions bound successfully');
      }
    } catch (e) {
      print('Whisper: FFI binding error = $e');
    }

    print('Whisper: load() = $_isLoaded');
    return _isLoaded;
  }

  /// Initialize model from file
  static Pointer<Void>? initFromFile(String modelPath) {
    print('Whisper: initFromFile($modelPath)');

    if (!_isLoaded) {
      if (!load()) return null;
    }

    if (!File(modelPath).existsSync()) {
      print('Whisper: FILE NOT FOUND');
      return null;
    }

    final stat = File(modelPath).statSync();
    print('Whisper: File size = ${stat.size} bytes');

    if (stat.size < 1000) {
      print('Whisper: FILE TOO SMALL');
      return null;
    }

    try {
      final pathPtr = modelPath.toNativeUtf8();
      _ctx = _initFromFile!(pathPtr);
      calloc.free(pathPtr);

      if (_ctx != null && _ctx != Pointer<Void>.fromAddress(0)) {
        print('Whisper: ctx = VALID ✅');
        return _ctx;
      } else {
        print('Whisper: ctx = NULL');
        return null;
      }
    } catch (e) {
      print('Whisper: initFromFile ERROR = $e');
      return null;
    }
  }

  /// Load WAV audio and convert to float32 PCM
  static Pointer<Float>? _loadWavAudio(String audioPath) {
    try {
      final file = File(audioPath);
      if (!file.existsSync()) {
        print('Whisper: Audio file NOT FOUND');
        return null;
      }
      
      final bytes = file.readAsBytesSync();
      print('Whisper: Audio bytes = ${bytes.length}');
      
      // Skip 44-byte WAV header, convert 16-bit PCM to float32
      int dataOffset = 44;
      int dataSize = bytes.length - dataOffset;
      final numSamples = dataSize ~/ 2;
      final samplesPtr = calloc<Float>(numSamples);
      
      for (int i = 0; i < numSamples; i++) {
        int sample = bytes[dataOffset + i * 2] | (bytes[dataOffset + i * 2 + 1] << 8);
        if (sample >= 32768) sample -= 65536;
        samplesPtr[i] = sample / 32768.0;
      }
      
      print('Whisper: Converted $numSamples samples');
      return samplesPtr;
    } catch (e) {
      print('Whisper: WAV load ERROR = $e');
      return null;
    }
  }

  /// Run full transcription - REAL FFI
  static String? full({
    required Pointer<Void> ctx,
    required String audioPath,
    bool withTimestamps = true,
  }) {
    print('Whisper: full()');

    if (ctx == null) return null;

    final samples = _loadWavAudio(audioPath);
    if (samples == null) return null;

    final file = File(audioPath);
    final bytes = file.readAsBytesSync();
    final numSamples = (bytes.length - 44) ~/ 2;

    print('Whisper: Processing $numSamples samples...');

    try {
      final result = _full!(ctx, 0, samples, numSamples);
      print('Whisper: whisper_full result = $result');
      calloc.free(samples);

      if (result != 0) {
        print('Whisper: whisper_full FAILED');
        return null;
      }

      final nSegments = _nSegments!(ctx);
      print('Whisper: n_segments = $nSegments');

      if (nSegments == 0) return null;

      final buffer = StringBuffer();
      for (int i = 0; i < nSegments; i++) {
        final textPtr = _getSegmentText!(ctx, i);
        if (textPtr != Pointer<Utf8>.fromAddress(0)) {
          if (buffer.isNotEmpty) buffer.write(' ');
          buffer.write(textPtr.toDartString());
        }
      }

      print('Whisper: Transcription = "${buffer.toString().substring(0, 50)}..."');
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
  }
}
