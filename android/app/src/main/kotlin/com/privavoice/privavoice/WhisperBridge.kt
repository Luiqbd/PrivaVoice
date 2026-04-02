package com.privavoice.privavoice

import android.content.Context
import kotlinx.coroutines.* // Add coroutine support
import mx.valdora.whisper.WhisperContext
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * Whisper Bridge - Uses mx.valdora whisper-android AAR
 * Provides 100% offline transcription with prebuilt ARM64 native libs
 */
class WhisperBridge private constructor() {
    
    private var whisperContext: WhisperContext? = null
    var isInitialized: Boolean = false
        private set
    
    companion object {
        @Volatile
        private var instance: WhisperBridge? = null
        
        fun getInstance(): WhisperBridge {
            return instance ?: synchronized(this) {
                instance ?: WhisperBridge().also { instance = it }
            }
        }
    }
    
    /**
     * Initialize Whisper model from file
     * @param modelPath Path to GGML model file (e.g., ggml-base.bin)
     */
    fun initialize(modelPath: String): Boolean {
        return try {
            whisperContext = WhisperContext(modelPath)
            isInitialized = true
            true
        } catch (e: Exception) {
            isInitialized = false
            false
        }
    }
    
    /**
     * Transcribe audio file to text (synchronous wrapper)
     * @param audioPath Path to audio file (WAV 16kHz mono recommended)
     * @return Transcribed text
     */
    @OptIn(ExperimentalCoroutinesApi::class)
    fun transcribe(audioPath: String): String {
        val ctx = whisperContext ?: throw IllegalStateException("Whisper not initialized")
        
        return runBlocking {
            try {
                val audioFile = java.io.File(audioPath)
                ctx.transcribe(audioFile) ?: ""
            } catch (e: Exception) {
                "Erro na transcrição: ${e.message}"
            }
        }
    }
    
    /**
     * Free model resources
     */
    fun release() {
        try {
            whisperContext?.close()
        } catch (e: Exception) {
            // Ignore
        }
        whisperContext = null
        isInitialized = false
    }
}

/**
 * Flutter Method Channel handler for Whisper
 */
class WhisperMethodChannel(private val context: Context) : MethodChannel.MethodCallHandler {
    
    private val whisper = WhisperBridge.getInstance()
    private val scope = CoroutineScope(Dispatchers.IO + SupervisorJob())
    
    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "init" -> {
                val modelPath = call.argument<String>("modelPath")
                if (modelPath == null) {
                    result.error("INVALID_ARGUMENT", "modelPath is required", null)
                    return
                }
                val success = whisper.initialize(modelPath)
                result.success(success)
            }
            
            "transcribe" -> {
                val audioPath = call.argument<String>("audioPath")
                if (audioPath == null) {
                    result.error("INVALID_ARGUMENT", "audioPath is required", null)
                    return
                }
                // Use async to handle suspend function
                scope.launch {
                    try {
                        val text = whisper.transcribe(audioPath)
                        result.success(text)
                    } catch (e: Exception) {
                        result.error("TRANSCRIBE_ERROR", e.message, null)
                    }
                }
            }
            
            "release" -> {
                whisper.release()
                result.success(true)
            }
            
            else -> result.notImplemented()
        }
    }
}
