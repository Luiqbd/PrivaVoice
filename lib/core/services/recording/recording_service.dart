import 'dart:async';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

/// Foreground Service for Audio Recording
/// Ensures recording continues even when app is backgrounded
class RecordingService {
  static const _channel = MethodChannel('com.privavoice/recording');
  
  static const String _channelId = 'privavoice_recording_channel';
  static const String _channelName = 'Gravação PrivaVoice';
  static const String _channelDescription = 'Mantém a gravação ativa em segundo plano';
  
  Timer? _autoSaveTimer;
  Timer? _durationTimer;
  String? _currentRecordingPath;
  DateTime? _recordingStartTime;
  Duration _currentDuration = Duration.zero;
  
  final _recordingStateController = StreamController<RecordingState>.broadcast();
  Stream<RecordingState> get recordingState => _recordingStateController.stream;
  
  final _durationController = StreamController<Duration>.broadcast();
  Stream<Duration> get durationStream => _durationController.stream;
  
  bool _isRecording = false;
  bool get isRecording => _isRecording;

  /// Start foreground service and begin recording
  Future<void> startRecording() async {
    if (_isRecording) return;

    try {
      // Create recording file
      final directory = await getApplicationDocumentsDirectory();
      final recordingsDir = Directory('${directory.path}/recordings');
      if (!await recordingsDir.exists()) {
        await recordingsDir.create(recursive: true);
      }
      
      final uuid = const Uuid().v4();
      _currentRecordingPath = '${recordingsDir.path}/recording_$uuid.m4a';
      _recordingStartTime = DateTime.now();
      
      // Start Android foreground service
      if (Platform.isAndroid) {
        await _channel.invokeMethod('startForegroundService', {
          'channelId': _channelId,
          'channelName': _channelName,
          'channelDescription': _channelDescription,
          'notificationTitle': 'PrivaVoice Gravando',
          'notificationText': 'Toque para retornar ao app',
        });
      }
      
      // Start recording
      await _channel.invokeMethod('startRecording', {
        'path': _currentRecordingPath,
      });
      
      _isRecording = true;
      
      // Start duration timer
      _durationTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (_recordingStartTime != null) {
          _currentDuration = DateTime.now().difference(_recordingStartTime!);
          _durationController.add(_currentDuration);
        }
      });
      
      // Start auto-save timer (every 30 seconds)
      _autoSaveTimer = Timer.periodic(const Duration(seconds: 30), (_) {
        _performAutoSave();
      });
      
      _recordingStateController.add(RecordingState(
        status: RecordingStatus.recording,
        path: _currentRecordingPath,
        duration: _currentDuration,
      ));
      
    } catch (e) {
      _recordingStateController.add(RecordingState(
        status: RecordingStatus.error,
        error: e.toString(),
      ));
    }
  }

  /// Pause recording
  Future<void> pauseRecording() async {
    if (!_isRecording) return;
    
    try {
      await _channel.invokeMethod('pauseRecording');
      
      _autoSaveTimer?.cancel();
      _durationTimer?.cancel();
      
      _recordingStateController.add(RecordingState(
        status: RecordingStatus.paused,
        path: _currentRecordingPath,
        duration: _currentDuration,
      ));
    } catch (e) {
      // Handle error
    }
  }

  /// Resume recording
  Future<void> resumeRecording() async {
    if (!_isRecording) return;
    
    try {
      await _channel.invokeMethod('resumeRecording');
      
      _autoSaveTimer = Timer.periodic(const Duration(seconds: 30), (_) {
        _performAutoSave();
      });
      
      _durationTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (_recordingStartTime != null) {
          _currentDuration = DateTime.now().difference(_recordingStartTime!);
          _durationController.add(_currentDuration);
        }
      });
      
      _recordingStateController.add(RecordingState(
        status: RecordingStatus.recording,
        path: _currentRecordingPath,
        duration: _currentDuration,
      ));
    } catch (e) {
      // Handle error
    }
  }

  /// Stop recording and return file path
  Future<RecordingResult?> stopRecording() async {
    if (!_isRecording) return null;
    
    try {
      _autoSaveTimer?.cancel();
      _durationTimer?.cancel();
      
      // Stop foreground service
      if (Platform.isAndroid) {
        await _channel.invokeMethod('stopForegroundService');
      }
      
      // Stop recording
      final result = await _channel.invokeMethod<Map>('stopRecording');
      
      _isRecording = false;
      
      if (result != null) {
        return RecordingResult(
          path: result['path'] as String,
          duration: Duration(milliseconds: result['duration'] as int),
          fileSize: result['size'] as int,
        );
      }
      
      return RecordingResult(
        path: _currentRecordingPath ?? '',
        duration: _currentDuration,
        fileSize: 0,
      );
    } catch (e) {
      _recordingStateController.add(RecordingState(
        status: RecordingStatus.error,
        error: e.toString(),
      ));
      return null;
    }
  }

  /// Perform auto-save every 30 seconds to prevent data loss
  Future<void> _performAutoSave() async {
    if (_currentRecordingPath == null) return;
    
    try {
      // Flush audio buffer to disk
      await _channel.invokeMethod('flushBuffer');
      
      // Get current recording state and save metadata
      final tempDir = await getApplicationDocumentsDirectory();
      final autoSaveDir = Directory('${tempDir.path}/autosave');
      if (!await autoSaveDir.exists()) {
        await autoSaveDir.create(recursive: true);
      }
      
      // Save checkpoint
      final checkpointPath = '${autoSaveDir.path}/checkpoint.json';
      final checkpointFile = File(checkpointPath);
      await checkpointFile.writeAsString('''
{
  "recordingPath": "$_currentRecordingPath",
  "startTime": "${_recordingStartTime?.toIso8601String()}",
  "lastAutoSave": "${DateTime.now().toIso8601String()}",
  "duration": ${_currentDuration.inMilliseconds}
}
''');
      
      print('Auto-save checkpoint: ${_currentDuration.inSeconds}s');
    } catch (e) {
      print('Auto-save failed: $e');
    }
  }

  /// Cancel recording and delete temp files
  Future<void> cancelRecording() async {
    _autoSaveTimer?.cancel();
    _durationTimer?.cancel();
    
    if (Platform.isAndroid) {
      await _channel.invokeMethod('stopForegroundService');
    }
    
    if (_currentRecordingPath != null) {
      final file = File(_currentRecordingPath!);
      if (await file.exists()) {
        await file.delete();
      }
    }
    
    _isRecording = false;
    _currentRecordingPath = null;
  }

  void dispose() {
    _autoSaveTimer?.cancel();
    _durationTimer?.cancel();
    _recordingStateController.close();
    _durationController.close();
  }
}

/// Recording state
class RecordingState {
  final RecordingStatus status;
  final String? path;
  final Duration? duration;
  final String? error;

  const RecordingState({
    required this.status,
    this.path,
    this.duration,
    this.error,
  });
}

enum RecordingStatus { idle, recording, paused, stopped, error }

/// Recording result after stop
class RecordingResult {
  final String path;
  final Duration duration;
  final int fileSize;

  const RecordingResult({
    required this.path,
    required this.duration,
    required this.fileSize,
  });
}
