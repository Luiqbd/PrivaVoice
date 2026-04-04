import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../../domain/entities/transcription.dart';
import '../datasources/app_database.dart';

class TranscriptionModel {
  static Transcription fromDbModel(TranscriptionData dbModel) {
    return Transcription(
      id: dbModel.id,
      title: dbModel.title,
      audioPath: dbModel.audioPath,
      text: dbModel.text,
      wordTimestamps: _parseWordTimestamps(dbModel.wordTimestampsJson),
      createdAt: dbModel.createdAt,
      duration: Duration(milliseconds: dbModel.durationMs),
      isEncrypted: dbModel.isEncrypted,
      speakerSegments: _parseSpeakerSegments(dbModel.speakerSegmentsJson),
      summary: dbModel.summary,
      actionItems: _parseActionItems(dbModel.actionItemsJson),
      notes: dbModel.notes,
      speakerNames: _parseSpeakerNames(dbModel.speakerNamesJson),
    );
  }
  
  static TranscriptionData toDbModel(Transcription entity) {
    return TranscriptionData(
      id: entity.id,
      title: entity.title,
      audioPath: entity.audioPath,
      text: entity.text,
      wordTimestampsJson: jsonEncode(
        entity.wordTimestamps.map((w) => {
          'word': w.word,
          'startTime': w.startTime.inMilliseconds,
          'endTime': w.endTime.inMilliseconds,
          'confidence': w.confidence,
        }).toList(),
      ),
      createdAt: entity.createdAt,
      durationMs: entity.duration.inMilliseconds,
      isEncrypted: entity.isEncrypted,
      speakerSegmentsJson: entity.speakerSegments != null 
        ? jsonEncode(entity.speakerSegments!.map((s) => {
            'speakerId': s.speakerId,
            'startTime': s.startTime.inMilliseconds,
            'endTime': s.endTime.inMilliseconds,
            'text': s.text,
          }).toList())
        : null,
      summary: entity.summary,
      actionItemsJson: entity.actionItems != null ? jsonEncode(entity.actionItems) : null,
      notes: entity.notes,
      speakerNamesJson: entity.speakerNames != null ? jsonEncode(entity.speakerNames) : null,
    );
  }
  
  static Map<String, String>? _parseSpeakerNames(String? json) {
    if (json == null || json.isEmpty) return null;
    try {
      final decoded = jsonDecode(json);
      if (decoded is Map) {
        return decoded.map((k, v) => MapEntry(k.toString(), v.toString()));
      }
    } catch (e) {
      debugPrint('TranscriptionModel: Error parsing speakerNames: $e');
    }
    return null;
  }
}
      
      static List<WordTimestamp> _parseWordTimestamps(String? json) {
    if (json == null || json.isEmpty || json == '[]') {
      return [];
    }
    try {
      final List<dynamic> list = jsonDecode(json);
      return list.map((item) => WordTimestamp(
        word: item['word'] as String,
        startTime: Duration(milliseconds: item['startTime'] as int),
        endTime: Duration(milliseconds: item['endTime'] as int),
        confidence: (item['confidence'] as num).toDouble(),
      )).toList();
    } catch (e) {
      debugPrint('TranscriptionModel: Failed to parse wordTimestamps: $e');
      return []; // Return empty if parsing fails
    }
  }
  
  static List<SpeakerSegment>? _parseSpeakerSegments(String? json) {
    if (json == null || json.isEmpty) return null;
    try {
      final List<dynamic> list = jsonDecode(json);
      return list.map((item) => SpeakerSegment(
        speakerId: item['speakerId'] as String,
        startTime: Duration(milliseconds: item['startTime'] as int),
        endTime: Duration(milliseconds: item['endTime'] as int),
        text: item['text'] as String,
      )).toList();
    } catch (e) {
      debugPrint('TranscriptionModel: Failed to parse speakerSegments: $e');
      return null;
    }
  }
  
  static List<String>? _parseActionItems(String? json) {
    if (json == null || json.isEmpty) return null;
    try {
      return List<String>.from(jsonDecode(json));
    } catch (e) {
      debugPrint('TranscriptionModel: Failed to parse actionItems: $e');
      return null;
    }
  }
}
