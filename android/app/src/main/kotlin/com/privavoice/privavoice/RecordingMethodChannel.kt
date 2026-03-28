package com.privavoice.privavoice

import android.content.Intent
import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class RecordingMethodChannel {
    
    companion object {
        private const val CHANNEL = "com.privavoice/recording"
    }
    
    fun registerWith(flutterEngine: FlutterEngine, activity: FlutterActivity) {
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "startForegroundService" -> {
                    val serviceIntent = Intent(activity, RecordingService::class.java)
                    
                    val channelId = call.argument<String>("channelId") ?: "default"
                    val channelName = call.argument<String>("channelName") ?: "Recording"
                    val channelDescription = call.argument<String>("channelDescription") ?: ""
                    val title = call.argument<String>("notificationTitle") ?: "Recording"
                    val text = call.argument<String>("notificationText") ?: ""
                    
                    // Start the foreground service
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                        activity.startForegroundService(serviceIntent)
                    } else {
                        activity.startService(serviceIntent)
                    }
                    
                    result.success(null)
                }
                
                "startRecording" -> {
                    val path = call.argument<String>("path")
                    if (path == null) {
                        result.error("INVALID_ARGS", "Path is required", null)
                        return@setMethodCallHandler
                    }
                    
                    val serviceIntent = Intent(activity, RecordingService::class.java).apply {
                        action = "START"
                        putExtra("path", path)
                    }
                    
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                        activity.startForegroundService(serviceIntent)
                    } else {
                        activity.startService(serviceIntent)
                    }
                    
                    result.success(null)
                }
                
                "pauseRecording" -> {
                    val serviceIntent = Intent(activity, RecordingService::class.java).apply {
                        action = "PAUSE"
                    }
                    activity.startService(serviceIntent)
                    result.success(null)
                }
                
                "resumeRecording" -> {
                    val serviceIntent = Intent(activity, RecordingService::class.java).apply {
                        action = "RESUME"
                    }
                    activity.startService(serviceIntent)
                    result.success(null)
                }
                
                "stopRecording" -> {
                    val serviceIntent = Intent(activity, RecordingService::class.java).apply {
                        action = "STOP"
                    }
                    activity.startService(serviceIntent)
                    result.success(null)
                }
                
                "flushBuffer" -> {
                    val serviceIntent = Intent(activity, RecordingService::class.java).apply {
                        action = "FLUSH"
                    }
                    activity.startService(serviceIntent)
                    result.success(null)
                }
                
                "stopForegroundService" -> {
                    val serviceIntent = Intent(activity, RecordingService::class.java)
                    activity.stopService(serviceIntent)
                    result.success(null)
                }
                
                else -> result.notImplemented()
            }
        }
    }
}
