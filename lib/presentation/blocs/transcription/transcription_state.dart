import 'package:equatable/equatable.dart';
import '../../../domain/entities/transcription.dart';

class TranscriptionLoading extends TranscriptionState {
  TranscriptionLoading() : super(status: TranscriptionStatus.loading);
}

enum TranscriptionStatus { initial, loading, loaded, processing, error }

class TranscriptionState extends Equatable {
  final TranscriptionStatus status;
  final List<Transcription> transcriptions;
  final Transcription? selectedTranscription;
  final int currentWordIndex;
  final Duration currentPosition;
  final String? errorMessage;
  final double processingProgress;
  final String? partialText;
  
  const TranscriptionState({
    this.status = TranscriptionStatus.initial,
    this.transcriptions = const <Transcription>[],
    this.selectedTranscription,
    this.currentWordIndex = 0,
    this.currentPosition = Duration.zero,
    this.errorMessage,
    this.processingProgress = 0.0,
    this.partialText,
  });
  
  TranscriptionState copyWith({
    TranscriptionStatus? status,
    List<Transcription>? transcriptions,
    Transcription? selectedTranscription,
    bool clearSelectedTranscription = false,
    int? currentWordIndex,
    Duration? currentPosition,
    String? errorMessage,
    double? processingProgress,
    String? partialText,
  }) {
    return TranscriptionState(
      status: status ?? this.status,
      transcriptions: transcriptions ?? this.transcriptions,
      selectedTranscription: clearSelectedTranscription ? null : (selectedTranscription ?? this.selectedTranscription),
      currentWordIndex: currentWordIndex ?? this.currentWordIndex,
      currentPosition: currentPosition ?? this.currentPosition,
      errorMessage: errorMessage,
      processingProgress: processingProgress ?? this.processingProgress,
    );
  }
  
  @override
  List<Object?> get props => [
    status, transcriptions, selectedTranscription, 
    currentWordIndex, currentPosition, errorMessage, processingProgress
  ];
}
