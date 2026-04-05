import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';

/// Audio Normalizer - Automatic Gain Control for clean transcription
/// 
/// Ensures audio is at optimal amplitude for Whisper:
/// - Target: -20dB to -12dB (speech optimal range)
/// - Prevents clipping and ensures whisper can hear clearly
class AudioNormalizer {
  static const int targetSampleRate = 16000;
  static const double targetDb = -18.0; // Optimal for speech (-20 to -12 dB)
  static const double maxAmplitude = 0.95; // Prevent clipping
  
  /// Normalize audio file to optimal gain
  static Future<String?> normalize(String inputPath, String outputPath) async {
    try {
      final file = File(inputPath);
      if (!await file.exists()) {
        debugPrint('AudioNormalizer: Input file not found');
        return null;
      }
      
      final bytes = await file.readAsBytes();
      final normalized = _normalizeWavBytes(bytes);
      
      final outFile = File(outputPath);
      await outFile.writeAsBytes(normalized);
      
      debugPrint('AudioNormalizer: Audio normalized successfully');
      return outputPath;
    } catch (e) {
      debugPrint('AudioNormalizer: Error: $e');
      return null;
    }
  }
  
  /// Normalize WAV bytes with automatic gain control
  static Uint8List _normalizeWavBytes(Uint8List wavData) {
    // Parse WAV header (44 bytes)
    if (wavData.length < 44) return wavData;
    
    final dataStart = 44;
    final dataSize = wavData.length - dataStart;
    if (dataSize <= 0) return wavData;
    
    // Get current peak amplitude
    double currentPeak = 0;
    for (var i = dataStart; i < wavData.length - 1; i += 2) {
      // Read 16-bit sample (little endian)
      final sample = wavData[i] | (wavData[i + 1] << 8);
      final signedSample = sample > 32767 ? sample - 65536 : sample;
      final normalized = signedSample.abs() / 32767.0;
      if (normalized > currentPeak) currentPeak = normalized;
    }
    
    if (currentPeak < 0.001) {
      debugPrint('AudioNormalizer: Audio is too quiet, no normalization needed');
      return wavData;
    }
    
    // Calculate gain adjustment
    double targetLinear = 0.5; // targetDb = -6 dB -> 0.5 linear
    if (currentPeak < 0.25) {
      // Very quiet - boost more aggressively
      targetLinear = maxAmplitude;
    } else if (currentPeak < 0.5) {
      // Moderate - boost slightly
      targetLinear = 0.8;
    } else if (currentPeak > maxAmplitude) {
      // Too loud - reduce but preserve dynamics
      targetLinear = 0.7;
    }
    
    final gain = targetLinear / currentPeak;
    if (gain > 4.0) {
      debugPrint('AudioNormalizer: Clamping gain to 4x to prevent artifacts');
    }
    
    final clampedGain = gain.clamp(0.5, 4.0);
    debugPrint('AudioNormalizer: Applying gain ${clampedGain.toStringAsFixed(2)}x (peak was ${currentPeak.toStringAsFixed(3)})');
    
    // Apply gain to samples
    final normalized = Uint8List.fromList(wavData);
    for (var i = dataStart; i < wavData.length - 1; i += 2) {
      // Read 16-bit sample
      var sample = wavData[i] | (wavData[i + 1] << 8);
      if (sample > 32767) sample -= 65536;
      
      // Apply gain
      var newSample = (sample * clampedGain).round();
      
      // Clip to prevent overflow
      if (newSample > 32767) newSample = 32767;
      if (newSample < -32768) newSample = -32768;
      
      // Convert back to unsigned
      var unsigned = newSample;
      if (unsigned < 0) unsigned += 65536;
      
      normalized[i] = unsigned & 0xFF;
      normalized[i + 1] = (unsigned >> 8) & 0xFF;
    }
    
    return normalized;
  }
}