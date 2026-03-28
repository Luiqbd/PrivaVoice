import 'dart:ffi';
import 'dart:io';
import 'package:ffi/ffi.dart';

/// Native function bindings for Whisper.cpp
/// Loads libwhisper.so at runtime for speech recognition
class WhisperBindings {
  static DynamicLibrary? _lib;
  static bool _isLoaded = false;

  // Function typedefs
  static Function? _whisper_init_from_file;
  static Function? _whisper_free;
  static Function? _whisper_full_default_params;
  static Function? _whisper_full;
  static Function? _whisper_full_n_segments;
  static Function? _whisper_full_get_segment_text;
  static Function? _whisper_full_get_segment_timestamps;

  /// Check if native library is available
  static bool get isAvailable => _isLoaded;

  /// Load the native library
  static bool load() {
    if (_isLoaded) return true;

    try {
      // Try to load the library based on platform
      if (Platform.isAndroid) {
        _lib = DynamicLibrary.open('libwhisper.so');
      } else if (Platform.isLinux) {
        _lib = DynamicLibrary.open('libwhisper.so');
      } else if (Platform.isMacOS) {
        _lib = DynamicLibrary.open('libwhisper.dylib');
      } else if (Platform.isWindows) {
        _lib = DynamicLibrary.open('libwhisper.dll');
      }

      if (_lib != null) {
        _bindFunctions();
        _isLoaded = true;
        print('Whisper native library loaded successfully');
        return true;
      }
    } catch (e) {
      print('Failed to load Whisper library: $e');
    }

    return false;
  }

  static void _bindFunctions() {
    if (_lib == null) return;

    // Bind Whisper functions
    _whisper_init_from_file = _lib!.lookupFunction<
        Pointer<Void> Function(Pointer<Utf8>),
        Pointer<Void> Function(Pointer<Utf8>)>('whisper_init_from_file');

    _whisper_free = _lib!.lookupFunction<
        Void Function(Pointer<Void>),
        void Function(Pointer<Void>)>('whisper_free');

    _whisper_full_default_params = _lib!.lookupFunction<
        Int32 Function(Int32),
        int Function(int)>('whisper_full_default_params');

    _whisper_full = _lib!.lookupFunction<
        Int32 Function(
            Pointer<Void>, Pointer<Void>, Pointer<Float>, Int32),
        int Function(
            Pointer<Void>, Pointer<Void>, Pointer<Float>, int)>('whisper_full');

    _whisper_full_n_segments = _lib!.lookupFunction<
        Int32 Function(Pointer<Void>),
        int Function(Pointer<Void>)>('whisper_full_n_segments');

    _whisper_full_get_segment_text = _lib!.lookupFunction<
        Pointer<Utf8> Function(Pointer<Void>, Int32),
        Pointer<Utf8> Function(Pointer<Void>, int)>('whisper_full_get_segment_text');

    _whisper_full_get_segment_timestamps = _lib!.lookupFunction<
        Int64 Function(Pointer<Void>, Int32),
        int Function(Pointer<Void>, int)>('whisper_full_get_segment_timestamps');
  }

  /// Initialize Whisper context from model file
  static Pointer<Void>? initFromFile(String modelPath) {
    if (!_isLoaded) {
      if (!load()) return null;
    }

    final pathPtr = modelPath.toNativeUtf8();
    try {
      final ctx = _whisper_init_from_file!(pathPtr);
      return ctx;
    } finally {
      calloc.free(pathPtr);
    }
  }

  /// Free Whisper context
  static void free(Pointer<Void> ctx) {
    if (_whisper_free != null && ctx != nullptr) {
      _whisper_free!(ctx);
    }
  }

  /// Get default parameters for Whisper decoding
  static int getDefaultParams(int strategy) {
    if (_whisper_full_default_params != null) {
      return _whisper_full_default_params!(strategy);
    }
    return 0;
  }

  /// Run full transcription
  static int full(Pointer<Void> ctx, Pointer<Float> samples, int samplesCount) {
    if (_whisper_full != null) {
      return _whisper_full!(ctx, samples, samplesCount);
    }
    return -1;
  }

  /// Get number of text segments
  static int getSegmentCount(Pointer<Void> ctx) {
    if (_whisper_full_n_segments != null) {
      return _whisper_full_n_segments!(ctx);
    }
    return 0;
  }

  /// Get text for segment
  static String getSegmentText(Pointer<Void> ctx, int iSegment) {
    if (_whisper_full_get_segment_text != null) {
      final textPtr = _whisper_full_get_segment_text!(ctx, iSegment);
      return textPtr.toDartString();
    }
    return '';
  }

  /// Free memory
  static void dispose() {
    _lib = null;
    _isLoaded = false;
  }
}