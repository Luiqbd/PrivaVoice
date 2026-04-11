package com.privavoice.privavoice

import android.content.Context
import io.github.ljcamargo.llamacpp.LlamaHelper

/**
 * Llama Bridge - Usa io.github.ljcamargo:llamacpp-kotlin:0.4.0 (Maven Central)
 * Fornece inferência GGUF offline
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
     * Load GGUF model
     */
    fun loadModel(path: String, callback: ((Boolean, String) -> Unit)? = null) {
        modelPath = path
        
        try {
            llama = LlamaHelper(context)
            
            llama?.load(
                path = path,
                contextLength = nCtx,
                onLoaded = {
                    isInitialized = true
                    callback?.invoke(true, "Model loaded: $path")
                }
            )
        } catch (e: Exception) {
            isInitialized = false
            callback?.invoke(false, "Error: ${e.message}")
        }
    }

    /**
     * Load from assets (need to copy first)
     */
    fun loadModelFromAssets(fileName: String, callback: ((Boolean, String) -> Unit)? = null) {
        val modelFile = context.cacheDir.resolve(fileName)
        
        if (modelFile.exists()) {
            loadModel(modelFile.absolutePath, callback)
        } else {
            callback?.invoke(false, "Model not found in cache: $fileName")
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
     * Streaming prediction
     */
    fun predictStream(prompt: String, onToken: (String) -> Unit, onComplete: () -> Unit) {
        val llamaInstance = llama
        if (llamaInstance == null || !llamaInstance.isLoaded) {
            onComplete()
            return
        }

        isProcessing = true
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

    /**
     * Stop current prediction
     */
    fun stop() {
        // LlamaHelper doesn't have explicit stop, but we mark processing as done
        isProcessing = false
    }

    /**
     * Release resources - CORRECT: called before Whisper starts
     */
    fun release() {
        stop()
        try {
            llama?.close()
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
            "library" to "llamacpp-kotlin:0.4.0"
        )
    }
}
