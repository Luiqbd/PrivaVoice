package com.privavoice.privavoice

import android.content.Context
import mx.valdora.whisper.WhisperContext
import java.io.File
import kotlinx.coroutines.runBlocking

/**
 * Whisper Bridge - Usa mx.valdora:whisper-android:1.0.0
 * API: mx.valdora.whisper.WhisperContext
 * 
 * Supported formats: WAV (16kHz, mono, PCM)
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
     * Load whisper model (whisper-base.bin)
     */
    fun loadModel(path: String, callback: ((Boolean, String) -> Unit)? = null) {
        modelPath = path
        
        try {
            whisperContext = WhisperContext(path)
            isInitialized = true
            callback?.invoke(true, "Model loaded: $path")
        } catch (e: Exception) {
            isInitialized = false
            callback?.invoke(false, "Error: ${e.message}")
        }
    }

    /**
     * Transcribe audio file (WAV, 16kHz mono PCM)
     * Uses runBlocking since transcribe is suspend
     */
    fun transcribe(audioPath: String, callback: (String) -> Unit) {
        val wc = whisperContext
        if (wc == null) {
            callback("Error: Whisper not initialized")
            return
        }

        try {
            // transcribe is suspend - use runBlocking
            val result = runBlocking {
                wc.transcribe(File(audioPath))
            }
            callback(result)
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
