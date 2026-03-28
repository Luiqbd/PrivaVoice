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
