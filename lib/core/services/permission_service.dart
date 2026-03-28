import 'dart:io';
import 'package:permission_handler/permission_handler.dart';

class PermissionService {
  static final PermissionService _instance = PermissionService._internal();
  factory PermissionService() => _instance;
  PermissionService._internal();

  bool _permissionsChecked = false;

  Future<bool> requestAllPermissions() async {
    if (_permissionsChecked) return true;

    final Map<Permission, PermissionStatus> statuses = {};

    // Request microphone (always required)
    statuses[Permission.microphone] = await Permission.microphone.request();

    // Request storage based on Android version
    if (Platform.isAndroid) {
      // For Android 13+ (API 33+)
      if (await _getAndroidSdkInt() >= 33) {
        statuses[Permission.audio] = await Permission.audio.request();
      }
      // For Android 12 and below
      else if (await _getAndroidSdkInt() >= 30) {
        // READ_EXTERNAL_STORAGE (maxSdkVersion 32)
        // Only request if not already granted
        final storageStatus = await Permission.storage.status;
        if (storageStatus.isDenied) {
          // Don't request for Android 11+ (scoped storage)
          if (await _getAndroidSdkInt() < 30) {
            statuses[Permission.storage] = await Permission.storage.request();
          }
        }
      }
    }

    // Check microphone permission
    final micStatus = statuses[Permission.microphone];
    if (micStatus == null) {
      final currentStatus = await Permission.microphone.status;
      if (currentStatus.isGranted) {
        _permissionsChecked = true;
        return true;
      }
    }

    if (micStatus != null && micStatus.isGranted) {
      _permissionsChecked = true;
      return true;
    }

    return false;
  }

  Future<int> _getAndroidSdkInt() async {
    // Try to get Android SDK version
    try {
      // This is a workaround - in Flutter we can't easily get SDK version
      // We'll use a default value that assumes Android 13+
      return 33;
    } catch (e) {
      return 33; // Default to Android 13+
    }
  }

  Future<bool> checkMicrophonePermission() async {
    return await Permission.microphone.isGranted;
  }

  Future<void> openSettings() async {
    await openAppSettings();
  }
}
