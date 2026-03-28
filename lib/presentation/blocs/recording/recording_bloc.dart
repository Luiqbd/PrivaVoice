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
  
  RecordingBloc() : super(RecordingState.initial()) {
    on<StartRecording>(_onStartRecording);
    on<StopRecording>(_onStopRecording);
    on<PauseRecording>(_onPauseRecording);
    on<ResumeRecording>(_onResumeRecording);
    on<UpdateAmplitude>(_onUpdateAmplitude);
    on<UpdateDuration>(_onUpdateDuration);
  }
  
  Future<void> _onStartRecording(
    StartRecording event,
    Emitter<RecordingState> emit,
  ) async {
    try {
      if (await _recorder.hasPermission()) {
        final directory = await getApplicationDocumentsDirectory();
        final filePath = '${directory.path}/recordings/${const Uuid().v4()}.m4a';
        
        // Create recordings directory
        await Directory('${directory.path}/recordings').create(recursive: true);
        
        await _recorder.start(
          const RecordConfig(
            encoder: AudioEncoder.aacLc,
            bitRate: 128000,
            sampleRate: 44100,
          ),
          path: filePath,
        );
        
        _startTime = DateTime.now();
        
        emit(state.copyWith(
          recording: state.recording.copyWith(
            status: RecordingStatus.recording,
            filePath: filePath,
            startedAt: _startTime,
          ),
        ));
        
        // Start amplitude monitoring
        _amplitudeTimer = Timer.periodic(
          const Duration(milliseconds: 100),
          (_) async {
            final amplitude = await _recorder.getAmplitude();
            add(UpdateAmplitude(amplitude.current));
          },
        );
        
        // Start duration timer
        _durationTimer = Timer.periodic(
          const Duration(seconds: 1),
          (_) {
            if (_startTime != null) {
              add(UpdateDuration(DateTime.now().difference(_startTime!)));
            }
          },
        );
        
        await HapticUtils.heavyImpact();
      }
    } catch (e) {
      emit(state.copyWith(error: e.toString()));
    }
  }
  
  Future<void> _onStopRecording(
    StopRecording event,
    Emitter<RecordingState> emit,
  ) async {
    try {
      _amplitudeTimer?.cancel();
      _durationTimer?.cancel();
      
      final path = await _recorder.stop();
      
      emit(state.copyWith(
        recording: state.recording.copyWith(
          status: RecordingStatus.idle,
          filePath: path,
        ),
      ));
      
      await HapticUtils.mediumImpact();
    } catch (e) {
      emit(state.copyWith(error: e.toString()));
    }
  }
  
  Future<void> _onPauseRecording(
    PauseRecording event,
    Emitter<RecordingState> emit,
  ) async {
    await _recorder.pause();
    _amplitudeTimer?.cancel();
    _durationTimer?.cancel();
    
    emit(state.copyWith(
      recording: state.recording.copyWith(status: RecordingStatus.paused),
    ));
    
    await HapticUtils.lightImpact();
  }
  
  Future<void> _onResumeRecording(
    ResumeRecording event,
    Emitter<RecordingState> emit,
  ) async {
    await _recorder.resume();
    
    _amplitudeTimer = Timer.periodic(
      const Duration(milliseconds: 100),
      (_) async {
        final amplitude = await _recorder.getAmplitude();
        add(UpdateAmplitude(amplitude.current));
      },
    );
    
    _durationTimer = Timer.periodic(
      const Duration(seconds: 1),
      (_) {
        if (_startTime != null) {
          add(UpdateDuration(DateTime.now().difference(_startTime!)));
        }
      },
    );
    
    emit(state.copyWith(
      recording: state.recording.copyWith(status: RecordingStatus.recording),
    ));
    
    await HapticUtils.lightImpact();
  }
  
  void _onUpdateAmplitude(
    UpdateAmplitude event,
    Emitter<RecordingState> emit,
  ) {
    emit(state.copyWith(
      recording: state.recording.copyWith(amplitude: event.amplitude),
    ));
  }
  
  void _onUpdateDuration(
    UpdateDuration event,
    Emitter<RecordingState> emit,
  ) {
    emit(state.copyWith(
      recording: state.recording.copyWith(duration: event.duration),
    ));
  }
  
  @override
  Future<void> close() {
    _amplitudeTimer?.cancel();
    _durationTimer?.cancel();
    _recorder.dispose();
    return super.close();
  }
}
