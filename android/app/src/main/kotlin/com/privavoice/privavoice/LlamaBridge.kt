package com.privavoice.privavoice

import android.content.ContentResolver
import android.content.Context
import kotlinx.coroutines.flow.MutableSharedFlow
import org.nehuatl.llamacpp.LlamaHelper

/**
 * Llama Bridge - Usa io.github.ljcamargo:llamacpp-kotlin:0.2.0
 * API: org.nehuatl.llamacpp.LlamaHelper
 */
class LlamaBridge(private val context: Context) {

    private var llama: LlamaHelper? = null
    private var modelPath: String = ""
    private var nCtx: Int = 2048

    var isInitialized: Boolean = false
        private set

    var isProcessing: Boolean = false
        private set

    companion object {
        @Volatile
        private var instance: LlamaBridge? = null

        fun getInstance(ctx: Context): LlamaBridge {
            return instance ?: synchronized(this) {
                instance ?: LlamaBridge(ctx).also { instance = it }
            }
        }
    }

    /**
     * Load GGUF model using ContentResolver
     */
    fun loadModel(path: String, callback: ((Boolean, String) -> Unit)? = null) {
        modelPath = path

        try {
            val sharedFlow = MutableSharedFlow<LlamaHelper.LLMEvent>()
            
            llama = LlamaHelper(
                contentResolver = context.contentResolver,
                sharedFlow = sharedFlow
            )

            llama?.load(path, nCtx) { contextId: Long ->
                isInitialized = true
                callback?.invoke(true, "Model loaded: $path (ctx: $contextId)")
            }
        } catch (e: Exception) {
            isInitialized = false
            callback?.invoke(false, "Error: ${e.message}")
        }
    }

    /**
     * Predict - uses coroutines internally
     */
    fun predict(prompt: String, callback: (String) -> Unit) {
        val llamaInstance = llama
        if (llamaInstance == null || llamaInstance.currentContext == null) {
            callback("Error: Model not loaded")
            return
        }

        isProcessing = true
        try {
            llamaInstance.predict(prompt)
            callback("Prediction started")
        } catch (e: Exception) {
            callback("Error: ${e.message}")
        } finally {
            isProcessing = false
        }
    }

    /**
     * Stop prediction
     */
    fun stop() {
        isProcessing = false
        llama?.stopPrediction()
    }

    /**
     * Release model resources
     */
    fun release() {
        stop()
        try {
            llama?.release()
            llama = null
            isInitialized = false
            println("LlamaBridge: Released successfully")
        } catch (e: Exception) {
            println("LlamaBridge: release error: ${e.message}")
        }
    }

    /**
     * Get model info
     */
    fun getModelInfo(): Map<String, Any> {
        return mapOf(
            "initialized" to isInitialized,
            "processing" to isProcessing,
            "modelPath" to modelPath,
            "library" to "llamacpp-kotlin:0.2.0"
        )
    }
}
