import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/services/ai_service.dart';
import '../../../core/ai/ai_state.dart';
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
    on<RenameTranscription>(_onRenameTranscription);
    on<SelectTranscription>(_onSelectTranscription);
    on<SeekToWord>(_onSeekToWord);
    on<UpdateSpeakerName>(_onUpdateSpeakerName);
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
      debugPrint('TranscriptionBloc error: $e');
      emit(state.copyWith(status: TranscriptionStatus.error));
    }
  }

  Future<void> _onProcessAudio(
    ProcessAudio event,
    Emitter<TranscriptionState> emit,
  ) async {
    emit(state.copyWith(
      status: TranscriptionStatus.processing,
      processingProgress: 0.0,
      clearSelectedTranscription: true,
      partialText: '',
    ));

    // Track partial text for real-time updates
    String partialText = '';

    try {
      emit(state.copyWith(processingProgress: 0.2));

      final transcription = await AIService.processAudio(
        audioPath: event.audioPath,
        title: event.title,
        onProgress: (prog, status) {
          // Real-time progress updates
          partialText = 'Transcrevendo: $status';
          emit(state.copyWith(
            processingProgress: prog,
            partialText: partialText,
          ));
        },
      );

      if (transcription == null) {
        throw Exception('AI processing returned null');
      }

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
      debugPrint('TranscriptionBloc process error: $e');
      emit(state.copyWith(
        status: TranscriptionStatus.error,
        errorMessage: e.toString(),
      ));
    } finally {
      _progressSubscription?.cancel();
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
      debugPrint('TranscriptionBloc delete error: $e');
    }
  }

  Future<void> _onRenameTranscription(
    RenameTranscription event,
    Emitter<TranscriptionState> emit,
  ) async {
    try {
      await _repository.updateTitle(event.id, event.newTitle);
      final transcriptions = await _repository.getAllTranscriptions();
      emit(state.copyWith(transcriptions: transcriptions));
    } catch (e) {
      debugPrint('TranscriptionBloc rename error: $e');
    }
  }

  Future<void> _onUpdateSpeakerName(
    UpdateSpeakerName event,
    Emitter<TranscriptionState> emit,
  ) async {
    try {
      await _repository.updateSpeakerName(
        event.transcriptionId,
        event.speakerId,
        event.newName,
      );
      // Reload the specific transcription
      final updated = await _repository.getTranscription(event.transcriptionId);
      if (updated != null) {
        final transcriptions = state.transcriptions.map((t) {
          return t.id == event.transcriptionId ? updated : t;
        }).toList();
        emit(state.copyWith(transcriptions: transcriptions));
      }
    } catch (e) {
      debugPrint('TranscriptionBloc update speaker name error: $e');
    }
  }

  void _onSelectTranscription(
    SelectTranscription event,
    Emitter<TranscriptionState> emit,
  ) {
    // Find transcription by id from current state
    final transcription = state.transcriptions.firstWhere(
      (t) => t.id == event.id,
      orElse: () => state.transcriptions.first,
    );
    emit(state.copyWith(selectedTranscription: transcription));
  }

  void _onSeekToWord(
    SeekToWord event,
    Emitter<TranscriptionState> emit,
  ) {
    // Implement seek functionality
  }
}
