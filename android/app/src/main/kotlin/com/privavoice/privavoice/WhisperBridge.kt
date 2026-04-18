package com.privavoice.privavoice

import android.content.Context
import mx.valdora.whisper.WhisperContext
import java.io.File
import java.util.concurrent.Executors
import kotlinx.coroutines.runBlocking
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext

/**
 * Whisper Bridge - mx.valdora:whisper-android:1.0.0
 * 
 * API:
 * 1. initialize(language) - loads libwhisper_android.so
 * 2. loadModel(path) - creates WhisperContext with model
 * 3. transcribe(audioPath) - transcribes WAV audio
 * 4. release() - frees resources
 */
class WhisperBridge(private val context: Context) {

    private var whisperContext: WhisperContext? = null
    var isInitialized: Boolean = false
        private set

    private var modelPath: String = ""

    companion object {
        @Volatile
        private var instance: WhisperBridge? = null

        fun getInstance(ctx: Context): WhisperBridge {
            return instance ?: synchronized(this) {
                instance ?: WhisperBridge(ctx).also { instance = it }
            }
        }
    }

    /**
     * Initialize Whisper library (loads libwhisper_android.so)
     */
    fun initialize(language: String = "pt", callback: ((Boolean, String) -> Unit)? = null) {
        try {
            System.loadLibrary("whisper_android")
            isInitialized = true
            callback?.invoke(true, "Whisper native library loaded")
        } catch (e: Exception) {
            isInitialized = false
            callback?.invoke(false, "Error: ${e.message}")
        }
    }

    /**
     * Load whisper-base.bin model and create WhisperContext
     */
    fun loadModel(path: String, language: String = "pt", callback: ((Boolean, String) -> Unit)? = null) {
        modelPath = path
        
        val file = File(path)
        if (!file.exists() || file.length() < 100_000_000) {
            callback?.invoke(false, "Invalid model file: $path")
            return
        }
        
        try {
            println("WhisperBridge: Creating WhisperContext with path: $path, language: $language")
            
            // Simple constructor - language is set via transcribe params
            whisperContext = WhisperContext(path)
            
            isInitialized = true
            println("WhisperBridge: WhisperContext created successfully!")
            callback?.invoke(true, "Model loaded: $path")
        } catch (e: Exception) {
            isInitialized = false
            println("WhisperBridge: Error loading model: ${e.message}")
            callback?.invoke(false, "Error loading model: ${e.message}")
        }
    }

    /**
     * Transcribe audio file (WAV, 16kHz mono PCM)
     * Uses runBlocking for suspend function
     * Note: Language is forced via Dart->Kotlin parameter
     */
    fun transcribe(audioPath: String, language: String = "pt", callback: (String) -> Unit) {
        val wc = whisperContext
        if (wc == null) {
            callback("Error: Whisper not initialized")
            return
        }

        println("WhisperBridge: Starting transcription (language=$language)...")

        // Run on executor to prevent blocking
        Executors.newSingleThreadExecutor().execute {
            try {
                // Use runBlocking for suspend function call
                val result = runBlocking {
                    wc.transcribe(File(audioPath))
                }
                println("WhisperBridge: Transcription done, ${result.length} chars")
                callback(result)

                // Force GC after transcription
                System.gc()
            } catch (e: Exception) {
                println("WhisperBridge: Transcription error: ${e.message}")
                callback("Error: ${e.message}")
                System.gc()
            }
        }
    }
    
    /**
     * Release Whisper context and free memory
     */
    fun releaseContext() {
        try {
            whisperContext?.close()
            whisperContext = null
            isInitialized = false
            System.gc()
            println("Whisper: Context released, memory freed")
        } catch (e: Exception) {
            println("Whisper: Release error: ${e.message}")
        }
    }

    /**
     * Start recording (future implementation)
     */
    fun startRecording(onResult: (String) -> Unit) {
        onResult("Recording not yet implemented")
    }

    /**
     * Stop recording
     */
    fun stopRecording() {
        // Not implemented yet
    }

    /**
     * Release resources - called before Llama starts
     */
    fun release() {
        try {
            whisperContext?.close()
            whisperContext = null
            isInitialized = false
            println("WhisperBridge: Released successfully")
        } catch (e: Exception) {
            println("WhisperBridge: release error: ${e.message}")
        }
    }

    /**
     * Get model info
     */
    fun getModelInfo(): Map<String, Any> {
        return mapOf(
            "initialized" to isInitialized,
            "modelPath" to modelPath,
            "library" to "mx.valdora:whisper-android:1.0.0",
            "native" to "libwhisper_android.so"
        )
    }
}
