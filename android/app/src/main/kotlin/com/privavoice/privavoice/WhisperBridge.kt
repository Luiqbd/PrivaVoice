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
     * Note: mx.valdora whisper-android uses multilingual models and auto-detects language
     * For Portuguese, ensure audio is clear and in pt-BR accent
     */
    fun initialize(modelPath: String): Boolean {
        return try {
            // mx.valdora WhisperContext - language is auto-detected from multilingual models
            whisperContext = WhisperContext(modelPath)
            isInitialized = true
            true
        } catch (e: Exception) {
            isInitialized = false
            false
        }
    }
    
    /**
     * Transcribe audio file to text
     * @param audioPath Path to audio file (WAV 16kHz mono recommended)
     * @param language Language code (e.g., "pt", "en", "es") - default "pt" for Portuguese
     * @return Transcribed text
     * 
     * Note: Post-processing fixes common Spanish->Portuguese confusions
     */
    @OptIn(ExperimentalCoroutinesApi::class)
    fun transcribe(audioPath: String, language: String = "pt"): String {
        val ctx = whisperContext ?: throw IllegalStateException("Whisper not initialized")
        
        return runBlocking {
            try {
                val audioFile = java.io.File(audioPath)
                // Transcribe - mx.valdora library doesn't support initial prompt
                val result = ctx.transcribe(audioFile) ?: ""
                
                // Post-process: Fix common Spanish->Portuguese confusions
                fixPortugueseTranscription(result)
            } catch (e: Exception) {
                "Erro na transcrição: ${e.message}"
            }
        }
    }
    
    /**
     * Fix common Spanish words that Whisper might confuse with Portuguese
     */
    private fun fixPortugueseTranscription(text: String): String {
        var result = text
        
        // Common confusions: Spanish -> Portuguese
        val corrections = mapOf(
            "hola" to "olá",
            "Hola" to "Olá",
            "qué tal" to "que tal",
            "Qué tal" to "Que tal",
            "me llamo" to "meu nome é",
            "Me llamo" to "Meu nome é",
            "estoy" to "estou",
            "Estoy" to "Estou",
            "ciudad" to "cidade",
            "Ciudad" to "Cidade",
            "brasil" to "Brasil",
            "el que" to "o que",
            "en el" to "no",
            "del" to "de",
            "los" to "os",
            "las" to "as",
            "una" to "uma",
            "uno" to "um",
            "pero" to "mas",
            "ahora" to "agora",
            "entonces" to "então",
            "dónde" to "onde",
            "cómo" to "como",
            "cuándo" to "quando"
        )
        
        for ((spanish, portuguese) in corrections) {
            result = result.replace(spanish, portuguese, ignoreCase = true)
        }
        
        return result
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
                val language = call.argument<String>("language") ?: "pt" // Default to Portuguese
                if (audioPath == null) {
                    result.error("INVALID_ARGUMENT", "audioPath is required", null)
                    return
                }
                // Use async to handle suspend function
                scope.launch {
                    try {
                        val text = whisper.transcribe(audioPath, language)
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
