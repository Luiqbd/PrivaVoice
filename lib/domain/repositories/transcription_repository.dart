import '../entities/transcription.dart';

abstract class TranscriptionRepository {
  Future<List<Transcription>> getAllTranscriptions();
  Future<Transcription?> getTranscriptionById(String id);
  Future<void> saveTranscription(Transcription transcription);
  Future<void> deleteTranscription(String id);
  Future<void> updateTranscription(Transcription transcription);
  Future<List<Transcription>> searchTranscriptions(String query);
}
