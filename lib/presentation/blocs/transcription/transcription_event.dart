import 'package:equatable/equatable.dart';

abstract class TranscriptionEvent extends Equatable {
  const TranscriptionEvent();
  @override
  List<Object?> get props => [];
}

class ProcessAudio extends TranscriptionEvent {
  final String audioPath;
  final String title;
  const ProcessAudio({required this.audioPath, required this.title});
  @override
  List<Object?> get props => [audioPath, title];
}

class LoadTranscriptions extends TranscriptionEvent {}

class DeleteTranscription extends TranscriptionEvent {
  final String id;
  const DeleteTranscription(this.id);
  @override
  List<Object?> get props => [id];
}

class RenameTranscription extends TranscriptionEvent {
  final String id;
  final String newTitle;
  const RenameTranscription(this.id, this.newTitle);
  @override
  List<Object?> get props => [id, newTitle];
}

class UpdateSpeakerName extends TranscriptionEvent {
  final String transcriptionId;
  final String speakerId;
  final String newName;
  const UpdateSpeakerName({
    required this.transcriptionId,
    required this.speakerId,
    required this.newName,
  });
  @override
  List<Object?> get props => [transcriptionId, speakerId, newName];
}

class SelectTranscription extends TranscriptionEvent {
  final String id;
  const SelectTranscription(this.id);
  @override
  List<Object?> get props => [id];
}

class SeekToWord extends TranscriptionEvent {
  final int wordIndex;
  const SeekToWord(this.wordIndex);
  @override
  List<Object?> get props => [wordIndex];
}
