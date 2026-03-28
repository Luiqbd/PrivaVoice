import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:ffi/ffi.dart';
import 'app.dart';
import 'core/utils/encryption_utils.dart';
import 'injection_container.dart';

/// Native library loaders for AI models
void _loadNativeLibraries() {
  try {
    if (Platform.isAndroid) {
      // Load Whisper library
      try {
        DynamicLibrary.open('libwhisper.so');
        print('Native: libwhisper.so loaded');
      } catch (e) {
        print('Native: Failed to load libwhisper.so - $e');
      }
      
      // Load Llama library  
      try {
        DynamicLibrary.open('libllama.so');
        print('Native: libllama.so loaded');
      } catch (e) {
        print('Native: Failed to load libllama.so - $e');
      }
    }
  } catch (e) {
    print('Native: Platform not Android, skipping');
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load native libraries BEFORE app starts
  _loadNativeLibraries();

  // Set system UI overlay style
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    systemNavigationBarColor: Color(0xFF0A0A0A),
    systemNavigationBarIconBrightness: Brightness.light,
  ));

  // Lock orientation to portrait
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
  ]);

  // Initialize encryption
  await EncryptionUtils.initialize();

  // Setup dependencies
  await setupDependencies();

  runApp(const PrivaVoiceApp());
}
