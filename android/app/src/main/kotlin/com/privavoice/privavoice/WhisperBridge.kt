package com.privavoice.privavoice

import android.content.Context
import android.content.res.AssetManager
import com.hadtun.whisperlib.WhisperLib
import com.hadtun.whisperlib.asr.Whisper
import com.hadtun.whisperlib.engine.WhisperEngine
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.*
import java.io.File

/**
 * Whisper Bridge - Uses HadesNull123/Whisper-Android-Lib
 * Provides offline transcription with TFLite + prebuilt native libs
 */
class WhisperBridge private constructor() {

    private var whisper: Whisper? = null
    private var appContext: Context? = null
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

    fun setContext(context: Context) {
        appContext = context
    }

    /**
     * Initialize Whisper with Portuguese language
     */
    fun initialize(language: String = "pt", callback: ((Boolean, String) -> Unit)? = null) {
        try {
            // Initialize WhisperLib
            val lib = WhisperLib.initialize()
            
            // Create Whisper instance
            whisper = Whisper.getInstance()
            
            // Configure for Portuguese
            whisper?.setLanguage(language)
            whisper?.setUseMultilingual(true)
            
            isInitialized = true
            callback?.invoke(true, "Whisper initialized with $language")
        } catch (e: Exception) {
            isInitialized = false
            callback?.invoke(false, "Error: ${e.message}")
        }
    }

    /**
     * Transcribe audio file
     */
    fun transcribe(audioPath: String, callback: (String) -> Unit) {
        val whisperInstance = whisper
        if (whisperInstance == null) {
            callback("Error: Whisper not initialized")
            return
        }

        try {
            whisperInstance.transcribe(
                audioFilePath = audioPath,
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
     * Start real-time recording and transcription
     */
    fun startRecording(onResult: (String) -> Unit) {
        val whisperInstance = whisper
        if (whisperInstance == null) {
            onResult("Error: Whisper not initialized")
            return
        }

        try {
            whisperInstance.startRecording(
                onResult = { text ->
                    onResult(text)
                },
                onError = { error ->
                    onResult("Error: $error")
                }
            )
        } catch (e: Exception) {
            onResult("Error: ${e.message}")
        }
    }

    /**
     * Stop recording
     */
    fun stopRecording() {
        try {
            whisper?.stopRecording()
        } catch (e: Exception) {
            println("WhisperBridge: stopRecording error: ${e.message}")
        }
    }

    /**
     * Release resources
     */
    fun release() {
        try {
            whisper?.stopRecording()
            whisper?.release()
            whisper = null
            isInitialized = false
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
            "engine" to (whisper != null).toString()
        )
    }
}
