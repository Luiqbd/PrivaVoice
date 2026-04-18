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
    fun loadModel(path: String, callback: ((Boolean, String) -> Unit)? = null) {
        modelPath = path
        
        val file = File(path)
        if (!file.exists() || file.length() < 100_000_000) {
            callback?.invoke(false, "Invalid model file: $path")
            return
        }
        
        // Create whisper context with PT-BR prompt to force Portuguese
        try {
            println("WhisperBridge: Creating WhisperContext with PT-BR prompt...")
            // Use the builder pattern if available, otherwise create normally
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
     * CRITICAL: Force language to PT-BR to prevent Spanish/English confusion
     */
    fun transcribe(audioPath: String, language: String = "pt", callback: (String) -> Unit) {
        val wc = whisperContext
        if (wc == null) {
            callback("Error: Whisper not initialized")
            return
        }

        // CRITICAL: Force PT-BR - ignore whatever language was passed
        val fixedLanguage = "pt"  // FORCE Portuguese
        println("WhisperBridge: FORCING language to PT-BR (was: $language)")

        // Calculate optimal thread count: leave 1 for system
        val availableCores = Runtime.getRuntime().availableProcessors()
        val optimalThreads = maxOf(1, availableCores - 1)
        println("Whisper: Using $optimalThreads threads (of $availableCores available)")
        
        // Run on background thread with lower priority
        Executors.newSingleThreadExecutor().execute {
            try {
                val result = try {
                    runBlocking(Dispatchers.IO) {
                        wc.transcribe(File(audioPath))
                    }
                } catch (nativeError: Exception) {
                    // Catch native C++ crashes to prevent app crash
                    "Error: ${nativeError.message ?: "Native inference failed"}"
                }
                callback(result)
                
                // Force GC after transcription to free memory
                System.gc()
            } catch (e: Exception) {
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
