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
  
  Duration get duration => recording.duration ?? Duration.zero;

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

// RecordingInProgress state
class RecordingInProgress extends RecordingState {
  RecordingInProgress({required Recording recording, String? error, bool isProcessing = false})
      : super(recording: recording, error: error, isProcessing: isProcessing);
}

// RecordingPaused state  
class RecordingPaused extends RecordingState {
  RecordingPaused({required Recording recording, String? error, bool isProcessing = false})
      : super(recording: recording, error: error, isProcessing: isProcessing);
}

// RecordingError state
class RecordingError extends RecordingState {
  final String errorMessage;
  
  RecordingError({required this.errorMessage, required Recording recording})
      : super(recording: recording);
  
  @override
  String get message => errorMessage;
}
