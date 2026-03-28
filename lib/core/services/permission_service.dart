import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';

class PermissionService {
  static final PermissionService _instance = PermissionService._internal();
  factory PermissionService() => _instance;
  PermissionService._internal();

  Future<bool> requestAllPermissions() async {
    debugPrint('PermissionService: Starting permission request...');
    
    // Request microphone permission
    final micStatus = await Permission.microphone.request();
    debugPrint('PermissionService: Microphone = ${micStatus.name}');
    
    if (micStatus.isPermanentlyDenied) {
      debugPrint('PermissionService: Microphone permanently denied, opening settings');
      await openAppSettings();
      return false;
    }
    
    // Request storage permissions based on Android version
    // For Android 13+ (API 33), we need READ_MEDIA_AUDIO
    // For Android 10-12, we use scoped storage but can request storage permission
    // For Android 9 and below, we need full storage permissions
    
    // Try to request storage permission
    final storageStatus = await Permission.storage.request();
    debugPrint('PermissionService: Storage = ${storageStatus.name}');
    
    // Also try audio permission for newer Android
    final audioStatus = await Permission.audio.request();
    debugPrint('PermissionService: Audio = ${audioStatus.name}');
    
    // Check if microphone is granted
    if (await Permission.microphone.isGranted) {
      debugPrint('PermissionService: Microphone granted! Success!');
      return true;
    }
    
    return false;
  }

  Future<bool> checkMicrophonePermission() async {
    return await Permission.microphone.isGranted;
  }

  Future<void> openSettings() async {
    await openAppSettings();
  }
}
