class AppConstants {
  AppConstants._();
  
  // App Info
  static const String appName = 'PrivaVoice';
  static const String appVersion = '1.0.0';
  
  // Pricing (Brazilian Real)
  static const double monthlyPrice = 149.40;
  static const double discountedPrice = 74.70;
  static const int trialDays = 7;
  
  // Security
  static const int autoSaveIntervalSeconds = 30;
  static const int biometricTimeoutMinutes = 5;
  
  // Audio
  static const int sampleRate = 16000;
  static const int maxRecordingDurationMinutes = 120;
  
  // AI Models
  static const String whisperModelName = 'whisper-base';
  static const String llmModelName = 'tinyllama-1.1b-4bit';
  
  // Onboarding
  static const int onboardingPageCount = 3;
}
