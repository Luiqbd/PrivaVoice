import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/haptic_utils.dart';
import '../../domain/entities/recording.dart';
import '../blocs/recording/recording_bloc.dart';
import '../blocs/recording/recording_event.dart';
import '../blocs/recording/recording_state.dart';

class RecordPage extends StatelessWidget {
  const RecordPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundPrimary,
      appBar: AppBar(
        title: const Text('PrivaVoice'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: () {},
          ),
        ],
      ),
      body: BlocBuilder<RecordingBloc, RecordingState>(
        builder: (context, state) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Recording indicator
                _buildRecordingIndicator(state.recording.status),
                const SizedBox(height: 32),
                // Duration display
                Text(
                  _formatDuration(state.recording.duration),
                  style: Theme.of(context).textTheme.displayLarge?.copyWith(
                    fontFamily: 'RobotoMono',
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 16),
                // Amplitude visualization
                _buildAmplitudeVisualizer(state.recording.amplitude),
                const SizedBox(height: 48),
                // Recording controls
                _buildRecordingControls(context, state.recording.status),
                const SizedBox(height: 24),
                // Status text
                Text(
                  _getStatusText(state.recording.status),
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildRecordingIndicator(RecordingStatus status) {
    if (status != RecordingStatus.recording) {
      return Container(
        width: 120,
        height: 120,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: AppColors.surface,
          border: Border.all(color: AppColors.surfaceVariant, width: 3),
        ),
        child: const Icon(Icons.mic, size: 60, color: AppColors.textSecondary),
      );
    }
    
    return Container(
      width: 120,
      height: 120,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: AppColors.primaryGradient,
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryAccent.withOpacity(0.5),
            blurRadius: 30,
            spreadRadius: 5,
          ),
        ],
      ),
      child: const Icon(Icons.mic, size: 60, color: AppColors.backgroundPrimary),
    );
  }

  Widget _buildAmplitudeVisualizer(double? amplitude) {
    final normalizedAmplitude = ((amplitude ?? -160) + 160) / 160;
    return Container(
      width: 200,
      height: 60,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        color: AppColors.surface,
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          FractionallySizedBox(
            widthFactor: normalizedAmplitude.clamp(0.0, 1.0),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(30),
                gradient: AppColors.primaryGradient,
              ),
            ),
          ),
          const Text('音量', style: TextStyle(color: AppColors.textTertiary)),
        ],
      ),
    );
  }

  Widget _buildRecordingControls(BuildContext context, RecordingStatus status) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (status == RecordingStatus.recording || status == RecordingStatus.paused)
          IconButton(
            onPressed: () {
              HapticUtils.mediumImpact();
              context.read<RecordingBloc>().add(StopRecording());
            },
            icon: Container(
              width: 72,
              height: 72,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.error,
              ),
              child: const Icon(Icons.stop, size: 36, color: AppColors.textPrimary),
            ),
          )
        else
          IconButton(
            onPressed: () {
              HapticUtils.heavyImpact();
              context.read<RecordingBloc>().add(StartRecording());
            },
            icon: Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: AppColors.primaryGradient,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primaryAccent.withOpacity(0.4),
                    blurRadius: 20,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: const Icon(Icons.mic, size: 40, color: AppColors.backgroundPrimary),
            ),
          ),
      ],
    );
  }

  String _formatDuration(Duration? duration) {
    final d = duration ?? Duration.zero;
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  String _getStatusText(RecordingStatus status) {
    switch (status) {
      case RecordingStatus.idle:
        return 'Toque para gravar';
      case RecordingStatus.recording:
        return 'Gravando...';
      case RecordingStatus.paused:
        return 'Pausado';
      case RecordingStatus.processing:
        return 'Processando...';
    }
  }
}
