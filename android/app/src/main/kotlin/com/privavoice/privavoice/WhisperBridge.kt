package com.privavoice.privavoice

import android.content.Context
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * Whisper Bridge - Stub implementation
 * 
 * Para ativar Whisper completo:
 * 1. Build manual do whisper-android: https://github.com/gouh/whisper-android
 * 2. Ou use alternativa: WhisperKit Android, whisper.cpp direto
 * 
 * O modelo whisper-base.bin já está em assets/models/
 * Precisa do libwhisper.so para funcionar
 */
class WhisperBridge private constructor() {

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
     * Initialize - stub
     */
    fun initialize(language: String = "pt", callback: ((Boolean, String) -> Unit)? = null) {
        isInitialized = true
        callback?.invoke(true, "Whisper STUB - precisa libwhisper.so")
    }

    /**
     * Transcribe - stub
     */
    fun transcribe(audioPath: String, callback: (String) -> Unit) {
        callback("Whisper STUB: Audio transcribe não disponível")
    }

    /**
     * Start recording - stub
     */
    fun startRecording(onResult: (String) -> Unit) {
        onResult("Whisper STUB: Recording não disponível")
    }

    /**
     * Stop recording
     */
    fun stopRecording() {
        println("WhisperBridge STUB: stopRecording")
    }

    /**
     * Release resources
     */
    fun release() {
        isInitialized = false
    }

    /**
     * Get model info
     */
    fun getModelInfo(): Map<String, Any> {
        return mapOf(
            "initialized" to isInitialized,
            "model" to "whisper-base.bin (stub)",
            "status" to "Aguardando libwhisper.so"
        )
    }
}
