import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';

class SpeakerAvatar extends StatelessWidget {
  final String speakerId;
  final bool isActive;
  final double size;

  const SpeakerAvatar({
    super.key,
    required this.speakerId,
    this.isActive = false,
    this.size = 48,
  });

  @override
  Widget build(BuildContext context) {
    // Generate avatar color based on speaker ID
    final color = _getSpeakerColor(speakerId);
    
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: isActive 
            ? LinearGradient(colors: [color, color.withOpacity(0.7)])
            : null,
        color: isActive ? null : color.withOpacity(0.3),
        border: Border.all(
          color: isActive ? color : color.withOpacity(0.5),
          width: isActive ? 3 : 2,
        ),
        boxShadow: isActive ? [
          BoxShadow(
            color: color.withOpacity(0.5),
            blurRadius: 12,
            spreadRadius: 2,
          ),
        ] : null,
      ),
      child: Center(
        child: Text(
          _getSpeakerInitials(speakerId),
          style: TextStyle(
            color: isActive ? Colors.white : color,
            fontSize: size * 0.4,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Color _getSpeakerColor(String speakerId) {
    // Different colors for different speakers
    final colors = [
      AppColors.primaryAccent,
      AppColors.secondaryAccent,
      AppColors.tertiaryAccent,
      AppColors.success,
      AppColors.warning,
    ];
    
    // Parse speaker number from ID (e.g., "speaker_1" -> 1)
    final speakerNum = int.tryParse(speakerId.replaceAll(RegExp(r'[^0-9]'), '')) ?? 1;
    return colors[(speakerNum - 1) % colors.length];
  }

  String _getSpeakerInitials(String speakerId) {
    // Extract speaker number
    final speakerNum = speakerId.replaceAll(RegExp(r'[^0-9]'), '');
    return 'P$speakerNum';  // P1, P2, etc.
  }
}
