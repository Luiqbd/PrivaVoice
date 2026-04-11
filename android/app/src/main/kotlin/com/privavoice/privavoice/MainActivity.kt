package com.privavoice.privavoice

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // Register Recording Method Channel
        RecordingMethodChannel().registerWith(flutterEngine, this)

        // Register Whisper Method Channel
        val whisperChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "com.privavoice/whisper"
        )
        
        val whisperBridge = WhisperBridge.getInstance(this)
        
        whisperChannel.setMethodCallHandler { call, result ->
            when (call.method) {
                "initialize" -> {
                    whisperBridge.initialize(call.argument<String>("language") ?: "pt") { success, message ->
                        if (success) result.success(mapOf("status" to "ok", "message" to message))
                        else result.error("INIT_ERROR", message, null)
                    }
                }
                "loadModel" -> {
                    val path = call.argument<String>("modelPath") ?: ""
                    whisperBridge.loadModel(path) { success, message ->
                        if (success) result.success(mapOf("status" to "ok", "message" to message))
                        else result.error("LOAD_ERROR", message, null)
                    }
                }
                "getModelInfo" -> result.success(whisperBridge.getModelInfo())
                "transcribe" -> {
                    val path = call.argument<String>("audioPath") ?: ""
                    whisperBridge.transcribe(path) { text ->
                        result.success(text)
                    }
                }
                "release" -> {
                    whisperBridge.release()
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }
    }
}
