import 'dart:convert';

import '../../domain/entities/transcription.dart';
import '../../domain/repositories/transcription_repository.dart';
import '../datasources/app_database.dart';
import '../models/transcription_model.dart';

class TranscriptionRepositoryImpl implements TranscriptionRepository {
  @override
  Future<List<Transcription>> getAllTranscriptions() async {
    final dbTranscriptions = await AppDatabase.getAllTranscriptions();
    return dbTranscriptions.map((t) => TranscriptionModel.fromDbModel(t)).toList();
  }
  
  @override
  Future<Transcription?> getTranscriptionById(String id) async {
    final dbTranscription = await AppDatabase.getTranscriptionById(id);
    if (dbTranscription == null) return null;
    return TranscriptionModel.fromDbModel(dbTranscription);
  }
  
  @override
  Future<void> saveTranscription(Transcription transcription) async {
    // Check if exists - if yes, update; if no, insert
    final existing = await AppDatabase.getTranscriptionById(transcription.id);
    if (existing != null) {
      await AppDatabase.updateTranscription(TranscriptionModel.toDbModel(transcription));
    } else {
      await AppDatabase.insertTranscription(TranscriptionModel.toDbModel(transcription));
    }
  }
  
  @override
  Future<void> deleteTranscription(String id) async {
    await AppDatabase.deleteTranscription(id);
  }
  
  @override
  Future<void> updateTranscription(Transcription transcription) async {
    await AppDatabase.updateTranscription(TranscriptionModel.toDbModel(transcription));
  }
  
  @override
  Future<List<Transcription>> searchTranscriptions(String query) async {
    final all = await getAllTranscriptions();
    final lowerQuery = query.toLowerCase();
    return all.where((t) => 
      t.title.toLowerCase().contains(lowerQuery) ||
      t.text.toLowerCase().contains(lowerQuery)
    ).toList();
  }
  
  @override
  Future<void> updateTitle(String id, String newTitle) async {
    final existing = await AppDatabase.getTranscriptionById(id);
    if (existing != null) {
      final updated = TranscriptionData(
        id: existing.id,
        title: newTitle,
        audioPath: existing.audioPath,
        text: existing.text,
        wordTimestampsJson: existing.wordTimestampsJson,
        createdAt: existing.createdAt,
        durationMs: existing.durationMs,
        isEncrypted: existing.isEncrypted,
        speakerSegmentsJson: existing.speakerSegmentsJson,
        summary: existing.summary,
        actionItemsJson: existing.actionItemsJson,
        notes: existing.notes,
        speakerNamesJson: existing.speakerNamesJson,
      );
      await AppDatabase.updateTranscription(updated);
    }
  }
  
  @override
  Future<Transcription?> getTranscription(String id) async {
    final dbTranscription = await AppDatabase.getTranscriptionById(id);
    if (dbTranscription == null) return null;
    return TranscriptionModel.fromDbModel(dbTranscription);
  }
  
  @override
  Future<void> updateSpeakerName(String transcriptionId, String speakerId, String newName) async {
    final existing = await AppDatabase.getTranscriptionById(transcriptionId);
    if (existing != null) {
      // Parse existing speaker names or create new map
      Map<String, String> speakerNames = {};
      if (existing.speakerNamesJson != null && existing.speakerNamesJson!.isNotEmpty) {
        try {
          // Parse JSON properly
          final decoded = jsonDecode(existing.speakerNamesJson!);
          if (decoded is Map) {
            speakerNames = decoded.map((k, v) => MapEntry(k.toString(), v.toString()));
          }
        } catch (e) {
          speakerNames = {};
        }
      }
      speakerNames[speakerId] = newName;
      
      final updated = TranscriptionData(
        id: existing.id,
        title: existing.title,
        audioPath: existing.audioPath,
        text: existing.text,
        wordTimestampsJson: existing.wordTimestampsJson,
        createdAt: existing.createdAt,
        durationMs: existing.durationMs,
        isEncrypted: existing.isEncrypted,
        speakerSegmentsJson: existing.speakerSegmentsJson,
        summary: existing.summary,
        actionItemsJson: existing.actionItemsJson,
        notes: existing.notes,
        speakerNamesJson: jsonEncode(speakerNames),
      );
      await AppDatabase.updateTranscription(updated);
    }
  }
}
