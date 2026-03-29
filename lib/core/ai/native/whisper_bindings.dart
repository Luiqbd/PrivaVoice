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

  /// Load native library and bind functions
  static bool load() {
    if (_isLoaded) return true;
    
    try {
      if (Platform.isAndroid) {
        _lib = DynamicLibrary.open('libwhisper.so');
      } else if (Platform.isLinux) {
        _lib = DynamicLibrary.open('libwhisper.so');
      } else if (Platform.isMacOS) {
        _lib = DynamicLibrary.open('libwhisper.dylib');
      }
      
      if (_lib != null) {
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

  /// Load WAV audio file and convert to float32 PCM samples
  static Pointer<Float>? _loadWavAudio(String audioPath, {int sampleRate = 16000}) {
    try {
      final file = File(audioPath);
      if (!file.existsSync()) {
        print('Whisper: Audio file NOT FOUND');
        return null;
      }
      
      final bytes = file.readAsBytesSync();
      print('Whisper: Audio raw bytes = ${bytes.length}');
      
      // Parse WAV header (44 bytes typical)
      // Skip header and parse PCM data
      int dataOffset = 44;
      int dataSize = bytes.length - dataOffset;
      
      // Convert to float32 samples
      final numSamples = dataSize ~/ 2; // 16-bit = 2 bytes
      final samplesPtr = calloc<Float>(numSamples);
      
      for (int i = 0; i < numSamples; i++) {
        // Read 16-bit signed sample
        int sample = bytes[dataOffset + i * 2] | 
                     (bytes[dataOffset + i * 2 + 1] << 8);
        if (sample >= 32768) sample -= 65536;
        
        // Convert to float (-1.0 to 1.0)
        samplesPtr[i] = sample / 32768.0;
      }
      
      print('Whisper: Converted $numSamples samples');
      return samplesPtr;
    } catch (e) {
      print('Whisper: WAV load ERROR = $e');
      return null;
    }
  }

  /// Run full transcription - REAL FFI IMPLEMENTATION
  static String? full({
    required Pointer<Void> ctx,
    required String audioPath,
    bool withTimestamps = true,
  }) {
    print('Whisper: full() - loading audio');
    
    if (ctx == null) {
      print('Whisper: ctx is NULL');
      return null;
    }
    
    // Load and convert audio
    final samples = _loadWavAudio(audioPath);
    if (samples == null) {
      print('Whisper: Failed to load audio');
      return null;
    }
    
    // Count samples (approximate - assuming 16-bit mono)
    final file = File(audioPath);
    final bytes = file.readAsBytesSync();
    final numSamples = (bytes.length - 44) ~/ 2;
    
    print('Whisper: Processing $numSamples samples with Whisper...');
    
    try {
      // Call whisper_full
      final result = _full!(ctx, 0, samples, numSamples);
      print('Whisper: whisper_full result = $result');
      
      calloc.free(samples);
      
      if (result != 0) {
        print('Whisper: whisper_full FAILED with code $result');
        return null;
      }
      
      // Get number of segments
      final nSegments = _nSegments!(ctx);
      print('Whisper: n_segments = $nSegments');
      
      if (nSegments == 0) {
        print('Whisper: No segments returned');
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
      print('Whisper: Transcription length = ${transcription.length}');
      print('Whisper: Transcription = "${transcription.substring(0, transcription.length > 100 ? 100 : transcription.length)}..."');
      
      return transcription;
    } catch (e) {
      print('Whisper: full() ERROR = $e');
      calloc.free(samples);
      return null;
    }
  }

  /// Get word timestamps
  static List<Map<String, dynamic>>? getWordTimestamps(Pointer<Void> ctx) {
    // TODO: Implement word-level timestamps from whisper tokenizer
    // For now, return empty list
    return [];
  }

  /// Free resources
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
    print('Whisper: disposed');
  }
}
