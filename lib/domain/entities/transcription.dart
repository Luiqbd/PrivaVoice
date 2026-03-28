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
  });
  
  @override
  List<Object?> get props => [
    id, title, audioPath, text, wordTimestamps, 
    createdAt, duration, isEncrypted, speakerSegments, 
    summary, actionItems
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
