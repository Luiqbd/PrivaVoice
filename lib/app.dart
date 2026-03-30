import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'core/theme/app_theme.dart';
import 'core/services/ai_service.dart';
import 'core/services/permission_service.dart';
import 'presentation/blocs/onboarding/onboarding_bloc.dart';
import 'presentation/blocs/recording/recording_bloc.dart';
import 'presentation/blocs/transcription/transcription_bloc.dart';
import 'presentation/pages/home_page.dart';
import 'presentation/pages/onboarding_page.dart';

class PrivaVoiceApp extends StatefulWidget {
  const PrivaVoiceApp({super.key});

  @override
  State<PrivaVoiceApp> createState() => _PrivaVoiceAppState();
}

class _PrivaVoiceAppState extends State<PrivaVoiceApp> {
  bool _showOnboarding = false;
  bool _permissionsRequested = false;
  final AIService _aiService = AIService();
  final PermissionService _permissionService = PermissionService();

  @override
  void initState() {
    super.initState();
    // Request permissions on first launch BEFORE AI init
    _requestPermissionsOnFirstLaunch();
  }

  Future<void> _requestPermissionsOnFirstLaunch() async {
    if (_permissionsRequested) return;
    _permissionsRequested = true;

    // Request all permissions FIRST
    final granted = await _permissionService.requestAllPermissions();
    debugPrint('Permissions granted: $granted');
    
    // AFTER permissions, initialize AI
    if (granted) {
      debugPrint('AI: Permissions granted, initializing AI...');
      AIService.initializeInBackground();
    }
    
    // Set system UI style
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Color(0xFF0A0A0A),
      systemNavigationBarIconBrightness: Brightness.light,
    ));
  }

  void _onOnboardingComplete() {
    setState(() {
      _showOnboarding = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PrivaVoice',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      home: _showOnboarding 
          ? OnboardingPage(onComplete: _onOnboardingComplete)
          : const HomePage(),
    );
  }
}
