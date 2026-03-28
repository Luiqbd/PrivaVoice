package com.privavoice.privavoice

/**
 * Llama Bridge - JNI interface to llama.cpp
 * Handles on-device LLM inference for summarization and NLP
 */
class LlamaBridge private constructor() {
    
    private var nativeContext: Long = 0
    var isInitialized: Boolean = false
        private set
    
    companion object {
        @Volatile
        private var instance: LlamaBridge? = null
        
        fun getInstance(): LlamaBridge {
            return instance ?: synchronized(this) {
                instance ?: LlamaBridge().also { instance = it }
            }
        }
    }
    
    /**
     * Initialize Llama model from file
     * @param modelPath Path to GGUF quantized model
     * @param nCtx Context size (default 2048)
     * @param nThreads Number of CPU threads (default 4)
     */
    fun initialize(modelPath: String, nCtx: Int = 2048, nThreads: Int = 4): Boolean {
        return try {
            nativeContext = nativeInit(modelPath, nCtx, nThreads)
            isInitialized = nativeContext != 0L
            isInitialized
        } catch (e: Exception) {
            isInitialized = false
            false
        }
    }
    
    /**
     * Generate completion/summary
     * @param prompt Input prompt (e.g., "Resuma: {transcription}")
     * @param maxTokens Maximum tokens to generate
     * @param temperature Temperature (0.0 - 1.0)
     * @param repeatPenalty Repeat penalty
     * @return Generated text
     */
    fun generate(
        prompt: String,
        maxTokens: Int = 256,
        temperature: Float = 0.7f,
        repeatPenalty: Float = 1.1f
    ): String {
        if (!isInitialized) {
            throw IllegalStateException("Llama not initialized. Call initialize() first.")
        }
        
        return try {
            nativeGenerate(nativeContext, prompt, maxTokens, temperature, repeatPenalty) ?: ""
        } catch (e: Exception) {
            "Erro na geração: ${e.message}"
        }
    }
    
    /**
     * Generate summary from transcription
     */
    fun summarize(transcription: String): String {
        val prompt = "Resuma o seguinte texto em pontos principais:\n\n$transcription"
        return generate(prompt, maxTokens = 256)
    }
    
    /**
     * Extract action items from transcription
     */
    fun extractActionItems(transcription: String): List<String> {
        val prompt = "Liste as ações/tarefas mencionadas no seguinte texto:\n\n$transcription"
        val result = generate(prompt, maxTokens = 128)
        return result.split("\n").filter { it.isNotBlank() && it.contains("-") }
    }
    
    /**
     * Answer question about transcription
     */
    fun answerQuestion(transcription: String, question: String): String {
        val prompt = "Com base no seguinte texto, responda à pergunta.\n\nTexto: $transcription\n\nPergunta: $question"
        return generate(prompt, maxTokens = 128)
    }
    
    /**
     * Get model info
     */
    fun getModelInfo(): String {
        return if (isInitialized) {
            try {
                nativeGetModelInfo(nativeContext) ?: "TinyLlama-1.1B-Q4"
            } catch (e: Exception) {
                "TinyLlama-1.1B-Q4"
            }
        } else "Not initialized"
    }
    
    /**
     * Reset conversation context
     */
    fun reset() {
        if (isInitialized) {
            try {
                nativeReset(nativeContext)
            } catch (e: Exception) {
                // Ignore
            }
        }
    }
    
    /**
     * Free model resources
     */
    fun release() {
        if (isInitialized && nativeContext != 0L) {
            try {
                nativeFree(nativeContext)
            } catch (e: Exception) {
                // Ignore
            }
            nativeContext = 0
            isInitialized = false
        }
    }
    
    // Native methods (implemented in C++)
    private external fun nativeInit(modelPath: String, nCtx: Int, nThreads: Int): Long
    private external fun nativeFree(contextPtr: Long)
    private external fun nativeGenerate(
        contextPtr: Long,
        prompt: String,
        maxTokens: Int,
        temperature: Float,
        repeatPenalty: Float
    ): String?
    private external fun nativeGetModelInfo(contextPtr: Long): String?
    private external fun nativeReset(contextPtr: Long)
    
    init {
        System.loadLibrary("llama")
    }
}
