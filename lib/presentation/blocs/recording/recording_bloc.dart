import 'dart:async';
import 'dart:io';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:uuid/uuid.dart';
import '../../../core/utils/haptic_utils.dart';
import '../../../domain/entities/recording.dart';
import 'recording_event.dart';
import 'recording_state.dart';

class RecordingBloc extends Bloc<RecordingEvent, RecordingState> {
  final AudioRecorder _recorder = AudioRecorder();
  Timer? _amplitudeTimer;
  Timer? _durationTimer;
  DateTime? _startTime;
  String? _currentFilePath;
  bool _isRecording = false;

  RecordingBloc() : super(RecordingState.initial()) {
    on<StartRecording>(_onStartRecording);
    on<StopRecording>(_onStopRecording);
    on<PauseRecording>(_onPauseRecording);
    on<ResumeRecording>(_onResumeRecording);
    on<UpdateAmplitude>(_onUpdateAmplitude);
    on<UpdateDuration>(_onUpdateDuration);
    on<CancelRecording>(_onCancelRecording);
  }

  bool get isRecording => _isRecording;

  Future<void> _onStartRecording(
    StartRecording event,
    Emitter<RecordingState> emit,
  ) async {
    try {
      print('RecordingBloc: Starting recording...');
      
      // Check permission
      final hasPermission = await _recorder.hasPermission();
      print('RecordingBloc: Has permission: $hasPermission');
      
      if (!hasPermission) {
        print('RecordingBloc: No permission!');
        emit(RecordingError(
          errorMessage: 'Sem permissão do microfone',
          recording: state.recording,
        ));
        return;
      }

      // Get directory
      final directory = await getApplicationDocumentsDirectory();
      final recordingsDir = Directory('${directory.path}/recordings');
      
      // Create recordings directory if not exists
      if (!await recordingsDir.exists()) {
        await recordingsDir.create(recursive: true);
        print('RecordingBloc: Created recordings directory');
      }
      
      _currentFilePath = '${recordingsDir.path}/${const Uuid().v4()}.m4a';
      print('RecordingBloc: File path: $_currentFilePath');

      // Start recording
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
      
      print('RecordingBloc: Recording started!');

      final newRecording = Recording(
        id: const Uuid().v4(),
        status: RecordingStatus.recording,
        filePath: _currentFilePath,
        startedAt: _startTime,
      );
      
      emit(RecordingInProgress(recording: newRecording));

      // Start amplitude monitoring
      _amplitudeTimer = Timer.periodic(
        const Duration(milliseconds: 100),
        (_) async {
          if (!_isRecording) return;
          try {
            final amplitude = await _recorder.getAmplitude();
            add(UpdateAmplitude(amplitude.current));
          } catch (e) {
            print('RecordingBloc: Amplitude error: $e');
          }
        },
      );

      // Start duration timer
      _durationTimer = Timer.periodic(
        const Duration(seconds: 1),
        (_) {
          if (!_isRecording || _startTime == null) return;
          add(UpdateDuration(DateTime.now().difference(_startTime!)));
        },
      );

      await HapticUtils.heavyImpact();
    } catch (e) {
      print('RecordingBloc: Error starting: $e');
      _isRecording = false;
      emit(RecordingError(errorMessage: e.toString(), recording: state.recording));
    }
  }

  Future<void> _onStopRecording(
    StopRecording event,
    Emitter<RecordingState> emit,
  ) async {
    try {
      print('RecordingBloc: Stopping recording...');
      _isRecording = false;
      _amplitudeTimer?.cancel();
      _durationTimer?.cancel();

      final path = await _recorder.stop();
      print('RecordingBloc: Stopped, path: $path');

      if (path == null || path.isEmpty) {
        print('RecordingBloc: ERROR - No file was recorded!');
        emit(RecordingError(
          errorMessage: 'Nenhum arquivo foi gravado',
          recording: state.recording,
        ));
        return;
      }

      // Verify file exists
      final file = File(path);
      final exists = await file.exists();
      print('RecordingBloc: File exists: $exists');
      
      if (exists) {
        final length = await file.length();
        print('RecordingBloc: File size: $length bytes');
      }

      final stoppedRecording = state.recording.copyWith(
        status: RecordingStatus.idle,
        filePath: path,
      );

      emit(RecordingState(
        recording: stoppedRecording,
      ));

      print('RecordingBloc: Recording saved successfully!');
      
      await HapticUtils.mediumImpact();
    } catch (e) {
      print('RecordingBloc: Error stopping: $e');
      emit(RecordingError(errorMessage: e.toString(), recording: state.recording));
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

    final pausedRecording = state.recording.copyWith(status: RecordingStatus.paused);
    emit(RecordingPaused(recording: pausedRecording));

    await HapticUtils.lightImpact();
  }

  Future<void> _onResumeRecording(
    ResumeRecording event,
    Emitter<RecordingState> emit,
  ) async {
    await _recorder.resume();
    _isRecording = true;

    _amplitudeTimer = Timer.periodic(
      const Duration(milliseconds: 100),
      (_) async {
        if (!_isRecording) return;
        try {
          final amplitude = await _recorder.getAmplitude();
          add(UpdateAmplitude(amplitude.current));
        } catch (e) {}
      },
    );

    _durationTimer = Timer.periodic(
      const Duration(seconds: 1),
      (_) {
        if (!_isRecording || _startTime == null) return;
        add(UpdateDuration(DateTime.now().difference(_startTime!)));
      },
    );

    final resumedRecording = state.recording.copyWith(status: RecordingStatus.recording);
    emit(RecordingInProgress(recording: resumedRecording));

    await HapticUtils.lightImpact();
  }

  void _onUpdateAmplitude(
    UpdateAmplitude event,
    Emitter<RecordingState> emit,
  ) {
    final updated = state.recording.copyWith(amplitude: event.amplitude);
    if (state is RecordingInProgress) {
      emit(RecordingInProgress(recording: updated));
    } else if (state is RecordingPaused) {
      emit(RecordingPaused(recording: updated));
    }
  }

  void _onUpdateDuration(
    UpdateDuration event,
    Emitter<RecordingState> emit,
  ) {
    final updated = state.recording.copyWith(duration: event.duration);
    if (state is RecordingInProgress) {
      emit(RecordingInProgress(recording: updated));
    } else if (state is RecordingPaused) {
      emit(RecordingPaused(recording: updated));
    }
  }

  Future<void> _onCancelRecording(
    CancelRecording event,
    Emitter<RecordingState> emit,
  ) async {
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
