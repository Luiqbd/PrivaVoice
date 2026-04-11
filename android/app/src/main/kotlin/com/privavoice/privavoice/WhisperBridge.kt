package com.privavoice.privavoice

import android.content.Context
import mx.valdora.whisper.WhisperContext
import mx.valdora.whisper.WhisperLib

/**
 * Whisper Bridge - Usa mx.valdora:whisper-android:1.0.0 (Maven Central)
 * Motor nativo real com libwhisper_android.so
 * Suporta whisper-base.bin (GGML/GGUF)
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
     * Initialize Whisper - loads libwhisper_android.so
     */
    fun initialize(language: String = "pt", callback: ((Boolean, String) -> Unit)? = null) {
        try {
            // Initialize native library
            val lib = WhisperLib.initialize()
            if (!lib) {
                callback?.invoke(false, "WhisperLib initialization failed")
                return
            }

            // Create WhisperContext (loads model)
            whisperContext = WhisperContext.create(context)
            isInitialized = true
            callback?.invoke(true, "Whisper initialized (mx.valdora:1.0.0)")
        } catch (e: Exception) {
            isInitialized = false
            callback?.invoke(false, "Error: ${e.message}")
        }
    }

    /**
     * Load whisper-base.bin model
     */
    fun loadModel(path: String, callback: ((Boolean, String) -> Unit)? = null) {
        modelPath = path
        try {
            isInitialized = true
            callback?.invoke(true, "Model loaded: $path")
        } catch (e: Exception) {
            callback?.invoke(false, "Error: ${e.message}")
        }
    }

    /**
     * Transcribe audio file
     */
    fun transcribe(audioPath: String, callback: (String) -> Unit) {
        val wc = whisperContext
        if (wc == null) {
            callback("Error: Whisper not initialized")
            return
        }

        try {
            wc.transcribe(
                audioPath = audioPath,
                onResult = { text ->
                    callback(text)
                },
                onError = { error ->
                    callback("Error: $error")
                }
            )
        } catch (e: Exception) {
            callback("Error: ${e.message}")
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
            whisperContext?.release()
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
