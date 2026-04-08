package com.privavoice.privavoice

import android.content.Context
import android.content.res.AssetManager
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.*

/**
 * Whisper Bridge - Stub implementation
 * Uses local Whisper model from assets/models/whisper-base.bin
 */
class WhisperBridgeStub private constructor() {
    private var appContext: Context? = null
    var isInitialized: Boolean = false
        private set

    companion object {
        @Volatile
        private var instance: WhisperBridgeStub? = null

        fun getInstance(): WhisperBridgeStub {
            return instance ?: synchronized(this) {
                instance ?: WhisperBridgeStub().also { instance = it }
            }
        }
    }

    fun initialize(context: Context) {
        appContext = context
        isInitialized = true
    }

    fun transcribe(audioPath: String, result: MethodChannel.Result) {
        if (!isInitialized) {
            result.error("NOT_INITIALIZED", "Whisper não foi inicializado", null)
            return
        }
        
        CoroutineScope(Dispatchers.IO).launch {
            try {
                // Stub: Returns placeholder transcription
                // TODO: Integrate with actual Whisper native library
                val transcription = "Transcrição Stub - Configure modelo Whisper"
                withContext(Dispatchers.Main) {
                    result.success(transcription)
                }
            } catch (e: Exception) {
                withContext(Dispatchers.Main) {
                    result.error("TRANSCRIPTION_ERROR", e.message, null)
                }
            }
        }
    }

    fun loadPortuguesePrompt(): String {
        // Load Portuguese context from assets
        return try {
            val context = appContext ?: return ""
            val inputStream = context.assets.open("pt-br/frases_basicas.txt")
            inputStream.bufferedReader().use { it.readText() }
        } catch (e: Exception) {
            ""
        }
    }

    fun release() {
        isInitialized = false
        appContext = null
    }
}