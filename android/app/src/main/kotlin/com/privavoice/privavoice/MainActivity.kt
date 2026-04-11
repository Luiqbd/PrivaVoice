package com.privavoice.privavoice

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // Register Recording Method Channel
        RecordingMethodChannel().registerWith(flutterEngine, this)

        // === Llama Channel ===
        val llamaChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "com.privavoice/llama"
        )
        
        val llamaBridge = LlamaBridge.getInstance(this)
        
        llamaChannel.setMethodCallHandler { call, result ->
            when (call.method) {
                "loadModel" -> {
                    val path = call.argument<String>("modelPath") ?: ""
                    llamaBridge.loadModel(path) { success, message ->
                        if (success) result.success(mapOf("status" to "ok", "message" to message))
                        else result.error("LOAD_ERROR", message, null)
                    }
                }
                "predict" -> {
                    val prompt = call.argument<String>("prompt") ?: ""
                    llamaBridge.predict(prompt) { text ->
                        result.success(text)
                    }
                }
                "release" -> {
                    llamaBridge.release()
                    result.success(true)
                }
                "getModelInfo" -> result.success(llamaBridge.getModelInfo())
                else -> result.notImplemented()
            }
        }

        // === Whisper Channel ===
        val whisperChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "com.privavoice/whisper"
        )
        
        val whisperBridge = WhisperBridge.getInstance(this)
        
        whisperChannel.setMethodCallHandler { call, result ->
            when (call.method) {
                "loadModel" -> {
                    val path = call.argument<String>("modelPath") ?: ""
                    whisperBridge.loadModel(path) { success, message ->
                        if (success) result.success(mapOf("status" to "ok", "message" to message))
                        else result.error("LOAD_ERROR", message, null)
                    }
                }
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
                "getModelInfo" -> result.success(whisperBridge.getModelInfo())
                else -> result.notImplemented()
            }
        }
    }
}
