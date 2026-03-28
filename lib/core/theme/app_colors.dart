import 'package:flutter/material.dart';

class AppColors {
  AppColors._();
  
  // Background Colors (Dark Mode)
  static const Color backgroundPrimary = Color(0xFF0A0A0A);
  static const Color backgroundSecondary = Color(0xFF141414);
  static const Color surface = Color(0xFF1E1E1E);
  static const Color surfaceVariant = Color(0xFF2A2A2A);
  
  // Neon Accent Colors
  static const Color primaryAccent = Color(0xFF00FFFF); // Cyan
  static const Color secondaryAccent = Color(0xFFFF00FF); // Magenta
  static const Color tertiaryAccent = Color(0xFF00FF88); // Neon Green
  
  // Status Colors
  static const Color success = Color(0xFF00FF88);
  static const Color error = Color(0xFFFF3366);
  static const Color warning = Color(0xFFFFAA00);
  
  // Text Colors
  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xFFB0B0B0);
  static const Color textTertiary = Color(0xFF707070);
  
  // Gradients
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [primaryAccent, secondaryAccent],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  
  static const LinearGradient darkGradient = LinearGradient(
    colors: [backgroundPrimary, backgroundSecondary],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );
}
