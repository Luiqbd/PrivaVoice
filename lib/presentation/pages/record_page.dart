import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/haptic_utils.dart';

class RecordPage extends StatefulWidget {
  const RecordPage({super.key});

  @override
  State<RecordPage> createState() => _RecordPageState();
}

class _RecordPageState extends State<RecordPage> with SingleTickerProviderStateMixin {
  bool _isRecording = false;
  bool _isPaused = false;
  Duration _recordingDuration = Duration.zero;
  Timer? _timer;
  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.15).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  void _startRecording() {
    setState(() {
      _isRecording = true;
      _isPaused = false;
    });
    _pulseController.repeat(reverse: true);
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() {
        _recordingDuration += const Duration(seconds: 1);
      });
    });
    HapticUtils.mediumImpact();
  }

  void _pauseRecording() {
    setState(() {
      _isPaused = true;
    });
    _timer?.cancel();
    _pulseController.stop();
    HapticUtils.lightImpact();
  }

  void _resumeRecording() {
    setState(() {
      _isPaused = false;
    });
    _pulseController.repeat(reverse: true);
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() {
        _recordingDuration += const Duration(seconds: 1);
      });
    });
    HapticUtils.mediumImpact();
  }

  void _stopRecording() {
    _timer?.cancel();
    _pulseController.stop();
    setState(() {
      _isRecording = false;
      _isPaused = false;
    });
    HapticUtils.heavyImpact();
    
    // Show success
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Gravação salva!'),
        backgroundColor: AppColors.primaryAccent,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundPrimary,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.all(24),
              child: Row(
                children: [
                  const Text(
                    'Nova Gravação',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const Spacer(),
                  if (_isRecording)
                    _buildLiveIndicator(),
                ],
              ),
            ),
            
            const Spacer(),
            
            // Recording Visualizer
            _buildRecordingVisualizer(),
            
            const SizedBox(height: 40),
            
            // Timer Display
            Text(
              _formatDuration(_recordingDuration),
              style: const TextStyle(
                fontSize: 48,
                fontWeight: FontWeight.w300,
                color: AppColors.textPrimary,
                letterSpacing: 4,
              ),
            ),
            
            const SizedBox(height: 8),
            
            // Status Text
            Text(
              _getStatusText(),
              style: TextStyle(
                fontSize: 16,
                color: _isRecording 
                    ? (_isPaused ? AppColors.tertiaryAccent : AppColors.primaryAccent)
                    : AppColors.textTertiary,
              ),
            ),
            
            const Spacer(),
            
            // Controls
            _buildControls(),
            
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildLiveIndicator() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.error.withOpacity(0.2),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.error, width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: const BoxDecoration(
              color: AppColors.error,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          const Text(
            'AO VIVO',
            style: TextStyle(
              color: AppColors.error,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecordingVisualizer() {
    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (context, child) {
        return Container(
          width: 200,
          height: 200,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: _isRecording 
                ? RadialGradient(
                    colors: [
                      AppColors.primaryAccent.withOpacity(0.3 * _pulseAnimation.value),
                      AppColors.primaryAccent.withOpacity(0.1 * _pulseAnimation.value),
                      Colors.transparent,
                    ],
                  )
                : null,
            color: _isRecording ? null : AppColors.surface,
            border: Border.all(
              color: _isRecording 
                  ? AppColors.primaryAccent.withOpacity(0.5)
                  : AppColors.surfaceVariant,
              width: 2,
            ),
            boxShadow: _isRecording ? [
              BoxShadow(
                color: AppColors.primaryAccent.withOpacity(0.3),
                blurRadius: 30 * _pulseAnimation.value,
                spreadRadius: 10 * _pulseAnimation.value,
              ),
            ] : null,
          ),
          child: Center(
            child: Container(
              width: 160,
              height: 160,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _isRecording ? AppColors.primaryAccent : AppColors.surface,
              ),
              child: Icon(
                _isRecording 
                    ? (_isPaused ? Icons.pause : Icons.mic)
                    : Icons.mic_none,
                size: 64,
                color: _isRecording 
                    ? AppColors.backgroundPrimary 
                    : AppColors.textTertiary,
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildControls() {
    if (!_isRecording) {
      // Start Recording Button
      return GestureDetector(
        onTap: _startRecording,
        child: Container(
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
          child: const Icon(
            Icons.mic,
            color: AppColors.backgroundPrimary,
            size: 36,
          ),
        ),
      );
    }

    // Recording Controls
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Cancel Button
        _buildControlButton(
          icon: Icons.close,
          onTap: () {
            setState(() {
              _isRecording = false;
              _isPaused = false;
              _recordingDuration = Duration.zero;
            });
            _timer?.cancel();
            _pulseController.stop();
          },
          color: AppColors.textTertiary,
        ),
        
        const SizedBox(width: 32),
        
        // Pause/Resume Button
        _buildControlButton(
          icon: _isPaused ? Icons.play_arrow : Icons.pause,
          onTap: _isPaused ? _resumeRecording : _pauseRecording,
          color: AppColors.secondaryAccent,
          isLarge: true,
        ),
        
        const SizedBox(width: 32),
        
        // Stop Button
        _buildControlButton(
          icon: Icons.stop,
          onTap: _stopRecording,
          color: AppColors.error,
        ),
      ],
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required VoidCallback onTap,
    required Color color,
    bool isLarge = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: isLarge ? 72 : 56,
        height: isLarge ? 72 : 56,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: AppColors.surface,
          border: Border.all(color: color, width: 2),
        ),
        child: Icon(icon, color: color, size: isLarge ? 32 : 24),
      ),
    );
  }

  String _getStatusText() {
    if (!_isRecording) return 'Toque para começar a gravar';
    if (_isPaused) return 'Gravação pausada';
    return 'Gravando...';
  }
}
