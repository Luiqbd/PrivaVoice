import 'package:equatable/equatable.dart';

enum RecordingStatus { idle, recording, paused, processing }

class Recording extends Equatable {
  final String id;
  final String? filePath;
  final RecordingStatus status;
  final Duration? duration;
  final DateTime? startedAt;
  final double? amplitude;
  final List<Duration>? bookmarks;
  
  const Recording({
    required this.id,
    this.filePath,
    this.status = RecordingStatus.idle,
    this.duration,
    this.startedAt,
    this.amplitude,
    this.bookmarks,
  });
  
  Recording copyWith({
    String? id,
    String? filePath,
    RecordingStatus? status,
    Duration? duration,
    DateTime? startedAt,
    double? amplitude,
  }) {
    return Recording(
      id: id ?? this.id,
      filePath: filePath ?? this.filePath,
      status: status ?? this.status,
      duration: duration ?? this.duration,
      startedAt: startedAt ?? this.startedAt,
      amplitude: amplitude ?? this.amplitude,
    );
  }
  
  @override
  List<Object?> get props => [id, filePath, status, duration, startedAt, amplitude];
}
