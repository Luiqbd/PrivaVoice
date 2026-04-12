import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'core/theme/app_theme.dart';
import 'core/ai/ai_state.dart';
import 'core/services/ai_service.dart';
import 'core/services/permission_service.dart';
import 'presentation/blocs/onboarding/onboarding_bloc.dart';
import 'presentation/pages/home_page.dart';
import 'presentation/pages/onboarding_page.dart';
import 'presentation/pages/setup_initial_page.dart';

class PrivaVoiceApp extends StatefulWidget {
  const PrivaVoiceApp({super.key});

  @override
  State<PrivaVoiceApp> createState() => _PrivaVoiceAppState();
}

class _PrivaVoiceAppState extends State<PrivaVoiceApp> {
  bool _showOnboarding = true;  // Show onboarding on first launch
  bool _permissionsRequested = false;
  bool _setupShown = false;  // Track if setup screen was shown
  final PermissionService _permissionService = PermissionService();
  Timer? _aiReadyTimer;

  @override
  void initState() {
    super.initState();
    // Request permissions on first launch BEFORE AI init
    _requestPermissionsOnFirstLaunch();
  }

  @override
  void dispose() {
    _aiReadyTimer?.cancel();
    super.dispose();
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

  // Called when setup page completes
  void _onSetupComplete() {
    setState(() {
      _setupShown = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => OnboardingBloc(),
      child: MaterialApp(
        title: 'PrivaVoice',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.darkTheme,
        home: _showOnboarding 
            ? OnboardingPage(onComplete: _onOnboardingComplete)
            : _buildAfterOnboarding(),
      ),
    );
  }

  Widget _buildAfterOnboarding() {
    // If setup was already shown, go to HomePage
    if (_setupShown) {
      return const HomePage();
    }
    
    // Show SetupInitialPage while AI initializes (always show for at least once)
    return SetupInitialPage(onComplete: _onSetupComplete);
  }

  void _onOnboardingComplete() {
    setState(() {
      _showOnboarding = false;
    });
  }
}
