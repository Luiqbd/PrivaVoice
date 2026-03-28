import 'dart:async';
import '../../../domain/entities/recording.dart';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:uuid/uuid.dart';
import '../../../core/utils/haptic_utils.dart';
import '../../../domain/entities/recording.dart';
import '../../../domain/entities/transcription.dart';
import '../../../data/repositories/transcription_repository_impl.dart';
import 'recording_event.dart';
import 'recording_state.dart';

class RecordingBloc extends Bloc<RecordingEvent, RecordingState> {
  final AudioRecorder _recorder = AudioRecorder();
  Timer? _amplitudeTimer;
  Timer? _durationTimer;
  DateTime? _startTime;
  String? _currentFilePath;
  bool _isRecording = false;
  final TranscriptionRepositoryImpl _repository = TranscriptionRepositoryImpl();

  RecordingBloc() : super(RecordingState.initial()) {
    on<StartRecording>(_onStartRecording);
    on<StopRecording>(_onStopRecording);
    on<PauseRecording>(_onPauseRecording);
    on<ResumeRecording>(_onResumeRecording);
    on<UpdateAmplitude>(_onUpdateAmplitude);
    on<UpdateDuration>(_onUpdateDuration);
    on<CancelRecording>(_onCancelRecording);
  }

  Future<void> _onStartRecording(
    StartRecording event,
    Emitter<RecordingState> emit,
  ) async {
    try {
      debugPrint('RecordingBloc: Starting...');
      
      final hasPermission = await _recorder.hasPermission();
      debugPrint('RecordingBloc: Has permission = $hasPermission');
      
      if (!hasPermission) {
        emit(RecordingError(
          errorMessage: 'Permissão do microfone negada',
          recording: state.recording,
        ));
        return;
      }

      final directory = await getApplicationDocumentsDirectory();
      final recordingsDir = Directory('${directory.path}/recordings');
      
      if (!await recordingsDir.exists()) {
        await recordingsDir.create(recursive: true);
        debugPrint('RecordingBloc: Created directory');
      }
      
      final filename = '${const Uuid().v4()}.m4a';
      _currentFilePath = '${recordingsDir.path}/$filename';
      debugPrint('RecordingBloc: Saving to $_currentFilePath');

      await _recorder.start(
        const RecordConfig(
          encoder: AudioEncoder.aacLc,
          bitRate: 128000,
          sampleRate: 44100,
        ),
        path: _currentFilePath!,
      );
      
      _isRecording = true;
      _startTime = DateTime.now();
      
      debugPrint('RecordingBloc: Recording started!');

      final newRecording = Recording(
        id: const Uuid().v4(),
        status: RecordingStatus.recording,
        filePath: _currentFilePath,
        startedAt: _startTime,
      );
      
      emit(RecordingInProgress(recording: newRecording));

      _amplitudeTimer = Timer.periodic(
        const Duration(milliseconds: 100),
        (_) async {
          if (!_isRecording) return;
          try {
            final amp = await _recorder.getAmplitude();
            add(UpdateAmplitude(amp.current));
          } catch (e) {
            debugPrint('Amplitude error: $e');
          }
        },
      );

      _durationTimer = Timer.periodic(
        const Duration(seconds: 1),
        (_) {
          if (!_isRecording || _startTime == null) return;
          add(UpdateDuration(DateTime.now().difference(_startTime!)));
        },
      );

      await HapticUtils.heavyImpact();
    } catch (e) {
      debugPrint('RecordingBloc: Start error: $e');
      _isRecording = false;
      emit(RecordingError(errorMessage: e.toString(), recording: state.recording));
    }
  }

  Future<void> _onStopRecording(
    StopRecording event,
    Emitter<RecordingState> emit,
  ) async {
    try {
      debugPrint('RecordingBloc: Stopping...');
      _isRecording = false;
      _amplitudeTimer?.cancel();
      _durationTimer?.cancel();

      final path = await _recorder.stop();
      debugPrint('RecordingBloc: Stopped, path = $path');

      if (path == null || path.isEmpty) {
        debugPrint('ERROR: No file recorded!');
        emit(RecordingError(
          errorMessage: 'Falha ao salvar gravação',
          recording: state.recording,
        ));
        return;
      }

      final file = File(path);
      if (await file.exists()) {
        final size = await file.length();
        debugPrint('RecordingBloc: File saved! Size: $size bytes');

        if (size > 0) {
          final stoppedRecording = state.recording.copyWith(
            status: RecordingStatus.idle,
            filePath: path,
          );
          emit(RecordingState(recording: stoppedRecording));
          
          // Save to database for library
          await _saveRecordingToLibrary(path, state.recording.duration ?? Duration.zero);
          
          await HapticUtils.mediumImpact();
        } else {
          emit(RecordingError(
            errorMessage: 'Arquivo vazio',
            recording: state.recording,
          ));
        }
      } else {
        emit(RecordingError(
          errorMessage: 'Arquivo não encontrado',
          recording: state.recording,
        ));
      }
    } catch (e) {
      debugPrint('RecordingBloc: Stop error: $e');
      emit(RecordingError(errorMessage: e.toString(), recording: state.recording));
    }
  }

  Future<void> _saveRecordingToLibrary(String path, Duration duration) async {
    try {
      final transcription = Transcription(
        id: const Uuid().v4(),
        title: 'Gravação ${DateTime.now().toString().substring(0, 16)}',
        audioPath: path,
        text: '',
        wordTimestamps: [],
        createdAt: DateTime.now(),
        duration: duration,
        isEncrypted: false,
      );
      
      await _repository.saveTranscription(transcription);
      debugPrint('RecordingBloc: Saved to library!');
    } catch (e) {
      debugPrint('RecordingBloc: Error saving to library: $e');
    }
  }

  Future<void> _onPauseRecording(
    PauseRecording event,
    Emitter<RecordingState> emit,
  ) async {
    await _recorder.pause();
    _isRecording = false;
    _amplitudeTimer?.cancel();
    _durationTimer?.cancel();
    final paused = state.recording.copyWith(status: RecordingStatus.paused);
    emit(RecordingPaused(recording: paused));
    await HapticUtils.lightImpact();
  }

  Future<void> _onResumeRecording(
    ResumeRecording event,
    Emitter<RecordingState> emit,
  ) async {
    await _recorder.resume();
    _isRecording = true;
    _amplitudeTimer = Timer.periodic(const Duration(milliseconds: 100), (_) async {
      if (!_isRecording) return;
      try {
        final amp = await _recorder.getAmplitude();
        add(UpdateAmplitude(amp.current));
      } catch (e) {}
    });
    _durationTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!_isRecording || _startTime == null) return;
      add(UpdateDuration(DateTime.now().difference(_startTime!)));
    });
    final resumed = state.recording.copyWith(status: RecordingStatus.recording);
    emit(RecordingInProgress(recording: resumed));
    await HapticUtils.lightImpact();
  }

  void _onUpdateAmplitude(UpdateAmplitude event, Emitter<RecordingState> emit) {
    final updated = state.recording.copyWith(amplitude: event.amplitude);
    if (state is RecordingInProgress) {
      emit(RecordingInProgress(recording: updated));
    } else if (state is RecordingPaused) {
      emit(RecordingPaused(recording: updated));
    }
  }

  void _onUpdateDuration(UpdateDuration event, Emitter<RecordingState> emit) {
    final updated = state.recording.copyWith(duration: event.duration);
    if (state is RecordingInProgress) {
      emit(RecordingInProgress(recording: updated));
    } else if (state is RecordingPaused) {
      emit(RecordingPaused(recording: updated));
    }
  }

  Future<void> _onCancelRecording(CancelRecording event, Emitter<RecordingState> emit) async {
    _isRecording = false;
    _amplitudeTimer?.cancel();
    _durationTimer?.cancel();
    await _recorder.stop();
    _currentFilePath = null;
    emit(RecordingState.initial());
  }

  @override
  Future<void> close() {
    _isRecording = false;
    _amplitudeTimer?.cancel();
    _durationTimer?.cancel();
    _recorder.dispose();
    return super.close();
  }
}
