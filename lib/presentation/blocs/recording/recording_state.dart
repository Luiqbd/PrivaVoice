import 'package:equatable/equatable.dart';
import '../../../domain/entities/recording.dart';

class RecordingState extends Equatable {
  final Recording recording;
  final String? error;
  final bool isProcessing;
  
  const RecordingState({
    required this.recording,
    this.error,
    this.isProcessing = false,
  });
  
  factory RecordingState.initial() {
    return RecordingState(
      recording: Recording(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        status: RecordingStatus.idle,
      ),
    );
  }
  
  RecordingState copyWith({
    Recording? recording,
    String? error,
    bool? isProcessing,
  }) {
    return RecordingState(
      recording: recording ?? this.recording,
      error: error,
      isProcessing: isProcessing ?? this.isProcessing,
    );
  }
  
  @override
  List<Object?> get props => [recording, error, isProcessing];
}

// Recording state subtypes for easier type checking
class RecordingInProgress extends RecordingState {
  RecordingInProgress({required super.recording, super.error, super.isProcessing}) 
    : super(recording: recording);
}

class RecordingPaused extends RecordingState {
  RecordingPaused({required super.recording, super.error, super.isProcessing}) 
    : super(recording: recording);
}

class RecordingError extends RecordingState {
  final String message;
  RecordingError({required this.message, required super.recording}) : super(recording: recording);
  
  @override
  String get message => message;
}
