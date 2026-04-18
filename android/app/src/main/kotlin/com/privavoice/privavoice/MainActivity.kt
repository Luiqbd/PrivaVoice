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

        // === Whisper Channel (mx.valdora) ===
        val whisperChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "com.privavoice/whisper"
        )
        
        val whisperBridge = WhisperBridge.getInstance(this)
        
        whisperChannel.setMethodCallHandler { call, result ->
            when (call.method) {
                "init" -> {
                    val path = call.argument<String>("modelPath") ?: ""
                    val language = call.argument<String>("language") ?: "pt"
                    // Initialize library AND load model in one call
                    whisperBridge.initialize(language) { success, initMsg ->
                        if (success) {
                            // NOW load the model (creates WhisperContext!)
                            whisperBridge.loadModel(path, language) { loadSuccess, loadMsg ->
                                if (loadSuccess) result.success(true)
                                else result.error("LOAD_ERROR", loadMsg, null)
                            }
                        } else {
                            result.error("INIT_ERROR", initMsg, null)
                        }
                    }
                }
                "loadModel" -> {
                    val path = call.argument<String>("modelPath") ?: ""
                    val language = call.argument<String>("language") ?: "pt"
                    whisperBridge.loadModel(path, language) { success, message ->
                        if (success) result.success(mapOf("status" to "ok", "message" to message))
                        else result.error("LOAD_ERROR", message, null)
                    }
                }
                "transcribe" -> {
                    val path = call.argument<String>("audioPath") ?: ""
                    // Force PT language to prevent Spanish transcription
                    val language = call.argument<String>("language") ?: "pt"
                    
                    // Synchronous transcribe - returns directly
                    var textResponse = ""
                    val semaphore = java.util.concurrent.CountDownLatch(1)
                    
                    whisperBridge.transcribe(path, language) { text ->
                        textResponse = text
                        semaphore.countDown()
                    }
                    
                    // Wait with timeout (60 seconds)
                    semaphore.await(60, java.util.concurrent.TimeUnit.SECONDS)
                    
                    if (textResponse.isNotEmpty()) {
                        result.success(textResponse)
                    } else {
                        result.error("TRANSCRIBE_ERROR", "Empty result or timeout", null)
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
