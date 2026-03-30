import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/services/ai_service.dart';
import '../../../domain/repositories/transcription_repository.dart';
import '../../../injection_container.dart';
import 'transcription_event.dart';
import 'transcription_state.dart';

class TranscriptionBloc extends Bloc<TranscriptionEvent, TranscriptionState> {
  
  final TranscriptionRepository _repository = getIt<TranscriptionRepository>();

  TranscriptionBloc() : super(const TranscriptionState()) {
    on<LoadTranscriptions>(_onLoadTranscriptions);
    on<ProcessAudio>(_onProcessAudio);
    on<DeleteTranscription>(_onDeleteTranscription);
    on<SelectTranscription>(_onSelectTranscription);
    on<SeekToWord>(_onSeekToWord);
  }

  Future<void> _onLoadTranscriptions(
    LoadTranscriptions event,
    Emitter<TranscriptionState> emit,
  ) async {
    debugPrint('TranscriptionBloc: Loading transcriptions...');
    emit(state.copyWith(status: TranscriptionStatus.loading));

    try {
      final transcriptions = await _repository.getAllTranscriptions();
      debugPrint('TranscriptionBloc: Loaded ${transcriptions.length} transcriptions');
      emit(state.copyWith(
        status: TranscriptionStatus.loaded,
        transcriptions: transcriptions,
      ));
    } catch (e) {
      debugPrint('TranscriptionBloc: Error loading - $e');
      emit(state.copyWith(
        status: TranscriptionStatus.error,
        errorMessage: e.toString(),
      ));
    }
  }

  Future<void> _onSelectTranscription(
    SelectTranscription event,
    Emitter<TranscriptionState> emit,
  ) async {
    debugPrint('TranscriptionBloc: Selecting transcription ${event.id}');
    try {
      final transcription = await _repository.getTranscriptionById(event.id);
      debugPrint('TranscriptionBloc: Found transcription: ${transcription?.title}');
      emit(state.copyWith(
        selectedTranscription: transcription,
        currentWordIndex: 0,
        currentPosition: Duration.zero,
      ));
    } catch (e) {
      debugPrint('TranscriptionBloc: Error selecting - $e');
    }
  }

  Future<void> _onProcessAudio(
    ProcessAudio event,
    Emitter<TranscriptionState> emit,
  ) async {
    emit(state.copyWith(
      status: TranscriptionStatus.processing,
      processingProgress: 0.0,
    ));

    try {
      emit(state.copyWith(processingProgress: 0.2));

      final transcription = await AIService.processAudio(
        audioPath: event.audioPath,
        title: event.title,
      );

      emit(state.copyWith(processingProgress: 0.8));
      await _repository.saveTranscription(transcription);
      emit(state.copyWith(processingProgress: 1.0));

      final transcriptions = await _repository.getAllTranscriptions();
      emit(state.copyWith(
        status: TranscriptionStatus.loaded,
        transcriptions: transcriptions,
        selectedTranscription: transcription,
      ));
    } catch (e) {
      emit(state.copyWith(
        status: TranscriptionStatus.error,
        errorMessage: e.toString(),
      ));
    }
  }

  Future<void> _onDeleteTranscription(
    DeleteTranscription event,
    Emitter<TranscriptionState> emit,
  ) async {
    try {
      await _repository.deleteTranscription(event.id);
      final transcriptions = await _repository.getAllTranscriptions();
      emit(state.copyWith(
        transcriptions: transcriptions,
        selectedTranscription: null,
      ));
    } catch (e) {
      emit(state.copyWith(
        status: TranscriptionStatus.error,
        errorMessage: e.toString(),
      ));
    }
  }

  void _onSeekToWord(SeekToWord event, Emitter<TranscriptionState> emit) {
    if (state.selectedTranscription == null) return;
    final timestamps = state.selectedTranscription!.wordTimestamps;
    if (event.wordIndex >= timestamps.length) return;
    final word = timestamps[event.wordIndex];
    emit(state.copyWith(
      currentWordIndex: event.wordIndex,
      currentPosition: word.startTime,
    ));
  }
}
