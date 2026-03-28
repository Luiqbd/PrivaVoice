import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'core/theme/app_theme.dart';
import 'presentation/blocs/onboarding/onboarding_bloc.dart';
import 'presentation/pages/home_page.dart';
import 'presentation/pages/onboarding_page.dart';

class PrivaVoiceApp extends StatefulWidget {
  const PrivaVoiceApp({super.key});

  @override
  State<PrivaVoiceApp> createState() => _PrivaVoiceAppState();
}

class _PrivaVoiceAppState extends State<PrivaVoiceApp> {
  bool _showOnboarding = true;

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(create: (_) => OnboardingBloc()),
      ],
      child: MaterialApp(
        title: 'PrivaVoice',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.darkTheme,
        home: _showOnboarding
            ? OnboardingPage(onComplete: () => setState(() => _showOnboarding = false))
            : const HomePage(),
      ),
    );
  }
}
