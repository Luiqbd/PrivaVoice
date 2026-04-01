import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:uuid/uuid.dart';
import '../../../core/utils/haptic_utils.dart';
import '../../../domain/entities/recording.dart';
import '../../../domain/entities/transcription.dart';
import '../../../data/models/transcription_model.dart';
import '../../../data/datasources/app_database.dart';
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

  Future<void> _onStartRecording(
    StartRecording event,
    Emitter<RecordingState> emit,
  ) async {
    try {
      debugPrint('RecordingBloc: Starting...');
      
      final hasPermission = await _recorder.hasPermission();
      debugPrint('RecordingBloc: Has permission = $hasPermission');
      
      if (!hasPermission) {
        debugPrint('RecordingBloc: No permission!');
        emit(RecordingError(
          errorMessage: 'Permissão do microfone negada',
          recording: state.recording,
        ));
        return;
      }

      final directory = await getApplicationDocumentsDirectory();
      final recordingsDir = Directory('${directory.path}/recordings');
      
      // Force directory creation with sync (CRITICAL - without this file has nowhere to live)
      if (!await recordingsDir.exists()) {
        recordingsDir.createSync(recursive: true);
        debugPrint('RecordingBloc: Created directory: ${recordingsDir.path}');
      }
      
      final filename = '${const Uuid().v4()}.wav';
      _currentFilePath = '${recordingsDir.path}/$filename';
      debugPrint('RecordingBloc: Recording will save to: $_currentFilePath');
      debugPrint('RecordingBloc: Directory exists: ${await recordingsDir.exists()}');

      await _recorder.start(
        const RecordConfig(
          encoder: AudioEncoder.wav,
          bitRate: 128000,
          sampleRate: 16000,
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
      
      // CRITICAL: Wait for filesystem to flush the .wav file
      await Future.delayed(const Duration(milliseconds: 500));
      
      debugPrint('RecordingBloc: Stopped, path = $path');

      if (path == null || path.isEmpty) {
        debugPrint('ERROR: No path returned from recorder!');
        emit(RecordingError(
          errorMessage: 'Falha ao salvar gravação',
          recording: state.recording,
        ));
        return;
      }

      // Verify file was actually created
      final file = File(path);
      try {
        if (!await file.exists()) {
          debugPrint('ERROR: File does not exist at: $path');
          emit(RecordingError(
            errorMessage: 'Arquivo não encontrado: $path',
            recording: state.recording,
          ));
          return;
        }
        
        final size = await file.length();
        debugPrint('RecordingBloc: Arquivo gerado em: $path');
        debugPrint('RecordingBloc: File size: $size bytes');

        if (size == 0) {
          debugPrint('ERROR: File has 0 bytes!');
          emit(RecordingError(
            errorMessage: 'Arquivo vazio',
            recording: state.recording,
          ));
          return;
        }

        // Update state
        final stoppedRecording = state.recording.copyWith(
          status: RecordingStatus.idle,
          filePath: path,
        );
        emit(RecordingState(recording: stoppedRecording));

        // Save to database IMMEDIATELY - no dependency on AI
        final transcriptionId = await _saveToDatabase(path, state.recording.duration ?? Duration.zero);
        
        if (transcriptionId.isEmpty) {
          debugPrint('ERROR: Failed to save to database!');
          emit(RecordingError(
            errorMessage: 'Falha ao salvar no banco de dados',
            recording: state.recording,
          ));
          return;
        }
        
        debugPrint('RecordingBloc: Saved with ID: $transcriptionId');
        
        // AI processes AFTER save (optional - user presses AI button)
        _triggerAIProcessingIfNeeded(path, transcriptionId);
        
        await HapticUtils.mediumImpact();
        debugPrint('RecordingBloc: All done!');
      } catch (e, st) {
        debugPrint('RecordingBloc: File error: $e');
        debugPrint('RecordingBloc: Stack: $st');
        emit(RecordingError(errorMessage: e.toString(), recording: state.recording));
      }
    } catch (e) {
      debugPrint('RecordingBloc: Stop error: $e');
      emit(RecordingError(errorMessage: e.toString(), recording: state.recording));
    }
  }

  Future<String> _saveToDatabase(String audioPath, Duration duration) async {
    try {
      debugPrint('RecordingBloc: Saving to database...');
      debugPrint('RecordingBloc: Saving to: $audioPath');
      
      final now = DateTime.now();
      final id = const Uuid().v4();
      final transcriptionData = TranscriptionData(
        id: id,
        title: 'Gravação ${now.day}/${now.month} ${now.hour}:${now.minute.toString().padLeft(2, '0')}',
        audioPath: audioPath,
        text: 'Processando...',
        wordTimestampsJson: '[]',
        createdAt: now,
        durationMs: duration.inMilliseconds,
        isEncrypted: false,
        speakerSegmentsJson: null,
        summary: null,
        actionItemsJson: null,
        notes: null, // Include notes field (can be null)
      );

      await AppDatabase.insertTranscription(transcriptionData);
      debugPrint('RecordingBloc: Saved successfully! ID: $id');
      return id;
    } catch (e, st) {
      debugPrint('RecordingBloc: Database error: $e');
      debugPrint('RecordingBloc: Stack trace: $st');
      return '';
    }
  }
  
  void _triggerAIProcessingIfNeeded(String audioPath, String transcriptionId) {
    // TODO: Trigger AI processing in background
    // For now, this is a placeholder - the user can press AI button to process
    debugPrint('RecordingBloc: AI processing ready for: $transcriptionId');
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
    
    // Wait for filesystem to flush
    await Future.delayed(const Duration(milliseconds: 500));
    
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
