package com.privavoice.privavoice

import io.github.ljcamargo.llamacpp.LlamaContext
import io.github.ljcamargo.llamacpp.LlamaHelper

/**
 * Llama Bridge - Usa io.github.ljcamargo:llamacpp-kotlin:0.2.0
 * IMPORTANTE: Libera Whisper antes de usar Llama (memória limitada)
 */
class LlamaBridge private constructor() {
    
    private var llamaContext: LlamaContext? = null
    private var modelPath: String = ""
    private var nCtx: Int = 2048
    private var nThreads: Int = 4
    
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
     * IMPORTANTE: Chame WhisperBridge.release() antes deste método!
     */
    fun initialize(modelPath: String, nCtx: Int = 2048, nThreads: Int = 4): Boolean {
        return try {
            this.modelPath = modelPath
            this.nCtx = nCtx
            this.nThreads = nThreads
            
            // Carrega modelo usando LlamaHelper
            llamaContext = LlamaHelper.load(
                path = modelPath,
                contextLength = nCtx,
                nThreads = nThreads
            )
            
            isInitialized = llamaContext != null
            println("LlamaBridge: Modelo carregado de $modelPath")
            isInitialized
        } catch (e: Exception) {
            println("LlamaBridge: Erro ao inicializar: ${e.message}")
            isInitialized = false
            false
        }
    }
    
    /**
     * Generate completion/summary
     * maxTokens padrão 200 para caber com system prompt
     */
    fun generate(
        prompt: String,
        maxTokens: Int = 200,
        temperature: Float = 0.7f,
        repeatPenalty: Float = 1.1f
    ): String {
        if (!isInitialized || llamaContext == null) {
            throw IllegalStateException("Llama not initialized. Call initialize() first.")
        }
        
        // System prompt de segurança (conciso)
        val systemPrompt = "Você é o PrivaVoice AI. Offline e seguro. Responda de forma concisa."
        val fullPrompt = "$systemPrompt\n\n$prompt"
        
        return try {
            // Usa LlamaContext para gerar
            llamaContext?.predict(fullPrompt) ?: ""
        } catch (e: Exception) {
            "Erro na geração: ${e.message}"
        }
    }
    
    fun summarize(transcription: String): String {
        val prompt = "Resuma: $transcription"
        return generate(prompt, maxTokens = 200)
    }
    
    fun extractActionItems(transcription: String): List<String> {
        val prompt = "Liste as ações: $transcription"
        val result = generate(prompt, maxTokens = 100)
        return result.split("\n").filter { it.isNotBlank() && it.contains("-") }
    }
    
    fun answerQuestion(transcription: String, question: String): String {
        val prompt = "Com base em: $transcription\n\nPergunta: $question"
        return generate(prompt, maxTokens = 150)
    }
    
    fun getModelInfo(): String {
        return if (isInitialized) "TinyLlama-1.1B-Q4 (loaded)" else "Not initialized"
    }
    
    fun reset() {
        llamaContext?.stop()
        println("LlamaBridge: Reset contexto")
    }
    
    /**
     * Libera memória do modelo
     * IMPORTANTE: Chamar ao sair do chat para liberar RAM
     */
    fun release() {
        try {
            llamaContext?.stop()
            llamaContext?.release()
        } catch (e: Exception) {
            println("LlamaBridge: Erro ao liberar: ${e.message}")
        }
        llamaContext = null
        isInitialized = false
        println("LlamaBridge: Memória liberada")
    }
}
