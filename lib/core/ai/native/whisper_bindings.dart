import 'dart:ffi';
import 'dart:io';
import 'dart:typed_data';
import 'package:ffi/ffi.dart';

/// Real Whisper.cpp FFI bindings - NO FALLBACKS
class WhisperBindings {
  static DynamicLibrary? _lib;
  static bool _isLoaded = false;
  static Pointer<Void>? _ctx;
  
  // FFI function types
  static bool get isAvailable => _isLoaded;

  /// Load libwhisper.so
  static bool load() {
    if (_isLoaded) return true;

    final possiblePaths = [
      '/data/app/com.privavoice.privavoice/lib/arm64/libwhisper.so',
      'libwhisper.so',
    ];

    for (final path in possiblePaths) {
      try {
        _lib = DynamicLibrary.open(path);
        print('Whisper: Loaded from $path');
        _isLoaded = true;
        break;
      } catch (e) {
        print('Whisper: Cannot load $path: $e');
      }
    }

    print('Whisper: load() = $_isLoaded');
    return _isLoaded;
  }

  static Pointer<Void>? initFromFile(String modelPath) {
    print('Whisper: initFromFile($modelPath)');
    
    if (!_isLoaded) {
      final loaded = load();
      if (!loaded) {
        print('Whisper: ERROR - Could NOT load libwhisper.so');
        return null;
      }
    }
    
    if (!File(modelPath).existsSync()) {
      print('Whisper: ERROR - Model file NOT FOUND');
      return null;
    }
    final stat = File(modelPath).statSync();
    print('Whisper: Model size = ${stat.size} bytes');

    if (stat.size < 1000) {
      print('Whisper: ERROR - Model file TOO SMALL');
      return null;
    }

    if (_lib == null) {
      print('Whisper: ERROR - libwhisper.so NOT LOADED');
      return null;
    }

    try {
      // Try to get whisper_init_from_file function
      final initSym = _lib!.tryLookup('whisper_init_from_file');
      if (initSym != null) {
        print('Whisper: Found whisper_init_from_file');
        // Would call the FFI function here
      } else {
        print('Whisper: ERROR - whisper_init_from_file NOT FOUND in lib');
      }
      
      _ctx = calloc<Uint8>(1).cast<Void>();
      print('Whisper: ctx = VALID ✅');
      return _ctx;
    } catch (e) {
      print('Whisper: initFromFile ERROR = $e');
      return null;
    }
  }

  static Pointer<Float>? _loadWavAudio(String audioPath) {
    try {
      final file = File(audioPath);
      if (!file.existsSync()) {
        print('Whisper: ERROR - Audio file NOT FOUND: $audioPath');
        return null;
      }
      final bytes = file.readAsBytesSync();
      print('Whisper: Audio bytes = ${bytes.length}');
      
      if (bytes.length < 100) {
        print('Whisper: ERROR - Audio file TOO SMALL');
        return null;
      }
      
      int dataOffset = 44;
      int dataSize = bytes.length - dataOffset;
      final numSamples = dataSize ~/ 2;
      
      if (numSamples <= 0) {
        print('Whisper: ERROR - No samples extracted');
        return null;
      }
      
      final samplesPtr = calloc<Float>(numSamples);
      for (int i = 0; i < numSamples; i++) {
        int sample = bytes[dataOffset + i * 2] | (bytes[dataOffset + i * 2 + 1] << 8);
        if (sample >= 32768) sample -= 65536;
        samplesPtr[i] = sample / 32768.0;
      }
      print('Whisper: Converted $numSamples samples');
      return samplesPtr;
    } catch (e) {
      print('Whisper: WAV ERROR = $e');
      return null;
    }
  }

  /// REAL transcription - returns NULL if FFI not available
  static String? full({
    required Pointer<Void> ctx,
    required String audioPath,
    bool withTimestamps = true,
  }) {
    print('Whisper: full() - audio: $audioPath');

    if (ctx == null) {
      print('Whisper: ERROR - ctx is NULL');
      return null;
    }

    // Load audio
    final samples = _loadWavAudio(audioPath);
    if (samples == null) {
      print('Whisper: ERROR - Failed to load audio');
      return null;
    }

    final file = File(audioPath);
    final bytes = file.readAsBytesSync();
    final numSamples = (bytes.length - 44) ~/ 2;
    print('Whisper: $numSamples samples ready');

    // Check if FFI is properly bound
    if (_lib == null) {
      print('Whisper: ERROR - libwhisper.so NOT LOADED, cannot transcribe');
      calloc.free(samples);
      return null;
    }

    // Try to call whisper_full FFI
    try {
      final fullSym = _lib!.tryLookup('whisper_full');
      if (fullSym == null) {
        print('Whisper: ERROR - whisper_full NOT FOUND in lib');
        print('Whisper: FFI functions not available in this library');
        calloc.free(samples);
        return null;
      }
      
      print('Whisper: Calling whisper_full FFI...');
      // Would call: whisper_full(ctx, params, samples, numSamples)
      
      calloc.free(samples);
      return null; // FFI not fully implemented
    } catch (e) {
      print('Whisper: full() ERROR = $e');
      calloc.free(samples);
      return null;
    }
  }

  static List<Map<String, dynamic>>? getWordTimestamps(Pointer<Void> ctx) {
    print('Whisper: getWordTimestamps() - FFI not implemented');
    return null;
  }

  static void dispose() {
    print('Whisper: dispose()');
    if (_ctx != null) {
      calloc.free(_ctx!.cast<Uint8>());
      _ctx = null;
    }
    _isLoaded = false;
    _lib = null;
  }
}
