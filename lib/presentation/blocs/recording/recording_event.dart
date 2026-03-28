import 'package:equatable/equatable.dart';


abstract class RecordingEvent extends Equatable {
  const RecordingEvent();
  @override
  List<Object?> get props => [];
}

class StartRecording extends RecordingEvent {}

class StopRecording extends RecordingEvent {}

class PauseRecording extends RecordingEvent {}

class ResumeRecording extends RecordingEvent {}

class UpdateAmplitude extends RecordingEvent {
  final double amplitude;
  const UpdateAmplitude(this.amplitude);
  @override
  List<Object?> get props => [amplitude];
}

class UpdateDuration extends RecordingEvent {
  final Duration duration;
  const UpdateDuration(this.duration);
  @override
  List<Object?> get props => [duration];
}

class ProcessRecording extends RecordingEvent {
  final String filePath;
  const ProcessRecording(this.filePath);
  @override
  List<Object?> get props => [filePath];
}
