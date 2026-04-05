import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import 'package:get_it/get_it.dart';
import '../../domain/entities/transcription.dart';
import '../../domain/repositories/transcription_repository.dart';
import '../../core/ai/whisper/whisper_service.dart';

/// Service to import external media files for transcription
class MediaImporter {
  static const _uuid = Uuid();
  
  /// Import audio file and transcribe it
  static Future<Transcription?> importAudio(String sourcePath, String title) async {
    try {
      debugPrint('MediaImporter: Starting import of $sourcePath');
      
      // Get app documents directory
      final appDir = await getApplicationDocumentsDirectory();
      final audioDir = Directory('${appDir.path}/recordings');
      if (!await audioDir.exists()) {
        await audioDir.create(recursive: true);
      }
      
      // Copy file to app directory
      final fileName = '${_uuid.v4()}.${sourcePath.split('.').last}';
      final destPath = '${audioDir.path}/$fileName';
      
      final sourceFile = File(sourcePath);
      await sourceFile.copy(destPath);
      
      debugPrint('MediaImporter: File copied to $destPath');
      
      // Get audio duration
      final duration = await _getAudioDuration(destPath);
      
      // Transcribe using Whisper
      debugPrint('MediaImporter: Starting transcription...');
      final whisperService = GetIt.instance<WhisperService>();
      final result = await whisperService.transcribe(destPath, 'pt');
      
      if (result == null || result.isEmpty) {
        debugPrint('MediaImporter: Transcription failed');
        return null;
      }
      
      // Create transcription entity
      final transcription = Transcription(
        id: _uuid.v4(),
        title: title,
        audioPath: destPath,
        text: result,
        wordTimestamps: [],
        createdAt: DateTime.now(),
        duration: duration,
        isEncrypted: true,
      );
      
      // Save to database
      final repo = GetIt.instance<TranscriptionRepository>();
      await repo.saveTranscription(transcription);
      
      debugPrint('MediaImporter: Import complete!');
      return transcription;
    } catch (e) {
      debugPrint('MediaImporter: Error: $e');
      return null;
    }
  }
  
  /// Get audio file duration (estimate from file size)
  static Future<Duration> _getAudioDuration(String path) async {
    try {
      final file = File(path);
      final size = await file.length();
      // Estimate: 128kbps = 16KB/s
      final seconds = (size / 16000).round();
      return Duration(seconds: seconds);
    } catch (e) {
      return Duration.zero;
    }
  }
}