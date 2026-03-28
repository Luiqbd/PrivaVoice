import 'package:equatable/equatable.dart';
import '../../../domain/entities/transcription.dart';

enum TranscriptionStatus { initial, loading, loaded, processing, error }

class TranscriptionState extends Equatable {
  final TranscriptionStatus status;
  final List<Transcription> transcriptions;
  final Transcription? selectedTranscription;
  final int currentWordIndex;
  final Duration currentPosition;
  final String? errorMessage;
  final double processingProgress;
  
  const TranscriptionState({
    this.status = TranscriptionStatus.initial,
    this.transcriptions = const <Transcription>[],
    this.selectedTranscription,
    this.currentWordIndex = 0,
    this.currentPosition = Duration.zero,
    this.errorMessage,
    this.processingProgress = 0.0,
  });
  
  TranscriptionState copyWith({
    TranscriptionStatus? status,
    List<Transcription>? transcriptions,
    Transcription? selectedTranscription,
    int? currentWordIndex,
    Duration? currentPosition,
    String? errorMessage,
    double? processingProgress,
  }) {
    return TranscriptionState(
      status: status ?? this.status,
      transcriptions: transcriptions ?? this.transcriptions,
      selectedTranscription: selectedTranscription ?? this.selectedTranscription,
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
