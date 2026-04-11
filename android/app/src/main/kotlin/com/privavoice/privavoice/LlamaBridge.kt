package com.privavoice.privavoice

import android.content.Context
import android.net.Uri
import io.github.ljcamargo.llamacpp.LlamaHelper
import kotlinx.coroutines.*

/**
 * Llama Bridge - Usa io.github.ljcamargo:llamacpp-kotlin:0.2.0
 * API: LlamaHelper com load(), predict(), isLoaded, close()
 */
class LlamaBridge(private val context: Context) {

    private var llama: LlamaHelper? = null
    private var modelPath: String = ""
    private var currentJob: Job? = null
    
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
     * Initialize and load the model
     */
    fun loadModel(path: String, callback: ((Boolean, String) -> Unit)? = null) {
        modelPath = path
        
        try {
            llama = LlamaHelper(context)
            
            llama?.load(
                path = path,
                contextLength = 2048,
                onLoaded = {
                    isInitialized = true
                    callback?.invoke(true, "Model loaded successfully")
                }
            )
        } catch (e: Exception) {
            isInitialized = false
            callback?.invoke(false, "Error: ${e.message}")
        }
    }

    /**
     * Load model from assets using URI
     */
    fun loadModelFromAssets(fileName: String, callback: ((Boolean, String) -> Unit)? = null) {
        // Try to get file from assets or cache
        val modelFile = context.cacheDir.resolve(fileName)
        
        if (modelFile.exists()) {
            loadModel(modelFile.absolutePath, callback)
        } else {
            // Need to copy from assets first
            callback?.invoke(false, "Model file not found: $fileName")
        }
    }

    /**
     * Synchronous prediction
     */
    fun predict(prompt: String, onResult: (String) -> Unit) {
        val llamaInstance = llama
        if (llamaInstance == null || !llamaInstance.isLoaded) {
            onResult("Error: Model not loaded")
            return
        }

        isProcessing = true
        try {
            val result = llamaInstance.predict(prompt)
            onResult(result)
        } catch (e: Exception) {
            onResult("Error: ${e.message}")
        } finally {
            isProcessing = false
        }
    }

    /**
     * Streaming prediction (real-time tokens)
     */
    fun predictStream(prompt: String, onToken: (String) -> Unit, onComplete: () -> Unit) {
        val llamaInstance = llama
        if (llamaInstance == null || !llamaInstance.isLoaded) {
            onComplete()
            return
        }

        isProcessing = true
        currentJob = CoroutineScope(Dispatchers.IO).launch {
            try {
                llamaInstance.predictStream(
                    prompt = prompt,
                    onToken = { token ->
                        onToken(token)
                    }
                )
            } catch (e: Exception) {
                println("predictStream error: ${e.message}")
            } finally {
                isProcessing = false
                onComplete()
            }
        }
    }

    /**
     * Stop current prediction
     */
    fun stop() {
        currentJob?.cancel()
        currentJob = null
        isProcessing = false
    }

    /**
     * Release resources
     */
    fun release() {
        stop()
        llama?.close()
        llama = null
        isInitialized = false
    }

    /**
     * Get model info
     */
    fun getModelInfo(): Map<String, Any> {
        return mapOf(
            "initialized" to isInitialized,
            "processing" to isProcessing,
            "modelPath" to modelPath
        )
    }
}
