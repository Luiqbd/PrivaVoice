import 'package:equatable/equatable.dart';

class Transcription extends Equatable {
  final String id;
  final String title;
  final String audioPath;
  final String text;
  final List<WordTimestamp> wordTimestamps;
  final DateTime createdAt;
  final Duration duration;
  final bool isEncrypted;
  final List<SpeakerSegment>? speakerSegments;
  final String? summary;
  final List<String>? actionItems;
  final String? notes; // Campo para notas do usuário
  
  // Custom speaker names (e.g., "Dr. Ricardo" instead of "Voz 1")
  final Map<String, String>? speakerNames; // speakerId -> customName
  
  const Transcription({
    required this.id,
    required this.title,
    required this.audioPath,
    required this.text,
    required this.wordTimestamps,
    required this.createdAt,
    required this.duration,
    this.isEncrypted = true,
    this.speakerSegments,
    this.summary,
    this.actionItems,
    this.notes,
    this.speakerNames,
  });
  
  /// Get display name for a speaker
  String getSpeakerDisplayName(String speakerId) {
    return speakerNames?[speakerId] ?? _defaultSpeakerName(speakerId);
  }
  
  String _defaultSpeakerName(String speakerId) {
    // Handle both "Voz 1" and "speaker_0" formats
    if (speakerId.startsWith('Voz ')) {
      return speakerId; // Already formatted
    }
    final index = int.tryParse(speakerId.replaceAll('speaker_', '')) ?? 0;
    return 'Voz ${index + 1}';
  }
  
  @override
  List<Object?> get props => [
    id, title, audioPath, text, wordTimestamps, 
    createdAt, duration, isEncrypted, speakerSegments, 
    summary, actionItems, notes, speakerNames
  ];
}

class WordTimestamp extends Equatable {
  final String word;
  final Duration startTime;
  final Duration endTime;
  final double confidence;
  
  const WordTimestamp({
    required this.word,
    required this.startTime,
    required this.endTime,
    required this.confidence,
  });
  
  @override
  List<Object?> get props => [word, startTime, endTime, confidence];
}

class SpeakerSegment extends Equatable {
  final String speakerId;
  final Duration startTime;
  final Duration endTime;
  final String text;
  
  const SpeakerSegment({
    required this.speakerId,
    required this.startTime,
    required this.endTime,
    required this.text,
  });
  
  @override
  List<Object?> get props => [speakerId, startTime, endTime, text];
}
