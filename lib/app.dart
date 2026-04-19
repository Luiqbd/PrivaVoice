import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:path_provider/path_provider.dart';
import 'core/theme/app_theme.dart';
import 'core/services/ai_service.dart';
import 'core/services/permission_service.dart';
import 'presentation/blocs/onboarding/onboarding_bloc.dart';
import 'presentation/pages/home_page.dart';
import 'presentation/pages/setup_initial_page.dart';

class PrivaVoiceApp extends StatefulWidget {
  const PrivaVoiceApp({super.key});

  @override
  State<PrivaVoiceApp> createState() => _PrivaVoiceAppState();
}

class _PrivaVoiceAppState extends State<PrivaVoiceApp> {
  bool? _isFirstTime;
  final PermissionService _permissionService = PermissionService();

  @override
  void initState() {
    super.initState();
    _checkInitialStatus();
  }

  Future<void> _checkInitialStatus() async {
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Color(0xFF0A0A0A),
      systemNavigationBarIconBrightness: Brightness.light,
    ));

    try {
      final appDir = await getApplicationDocumentsDirectory();
      final whisperFile = File('${appDir.path}/models/${AIService.whisperFilename}');
      final exists = await whisperFile.exists();
      
      setState(() {
        _isFirstTime = !exists;
      });

      // Se os modelos já existem, inicializa em background e pede permissões (caso faltem)
      if (exists) {
        AIService.initializeInBackground();
        // Não bloqueia a Home se já tiver os arquivos, mas garante que temos permissão
        _permissionService.requestAllPermissions();
      } else {
        // Se for a primeira vez, apenas inicia o carregamento. 
        // As permissões serão pedidas após o SetupInitialPage.
        AIService.initializeInBackground();
      }
      
    } catch (e) {
      setState(() {
        _isFirstTime = true;
      });
      AIService.initializeInBackground();
    }
  }

  /// Chamado apenas após o término do carregamento da IA
  Future<void> _onSetupComplete() async {
    // Agora que a IA está pronta, pedimos as permissões (Microfone, etc)
    // Isso evita assustar o usuário logo no primeiro segundo de app
    await _permissionService.requestAllPermissions();
    
    setState(() {
      _isFirstTime = false;
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
        home: _buildInitialRoute(),
      ),
    );
  }

  Widget _buildInitialRoute() {
    if (_isFirstTime == null) {
      return const Scaffold(
        backgroundColor: Color(0xFF0A0A0A),
        body: Center(child: CircularProgressIndicator(color: Colors.white)),
      );
    }

    if (_isFirstTime == false) {
      return const HomePage();
    }

    // Tela de carregamento da IA
    return SetupInitialPage(onComplete: _onSetupComplete);
  }
}
