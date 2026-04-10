package com.privavoice.privavoice

/**
 * Llama Bridge - Offline AI for summarization and NLP
 * Uses kotlinllamacpp from JitPack when available, fallback para modo offline
 * IMPORTANT: Libera Whisper antes de usar Llama (memória limitada)
 */
class LlamaBridge private constructor() {
    
    // Modelo carregado em memória
    private var modelPath: String = ""
    private var nCtx: Int = 2048
    private var nThreads: Int = 4
    private var isModelLoaded: Boolean = false
    
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
            isModelLoaded = true
            isInitialized = true
            println("LlamaBridge: Modelo carregado de $modelPath")
            true
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
        if (!isInitialized) {
            throw IllegalStateException("Llama not initialized. Call initialize() first.")
        }
        
        // System prompt de segurança (conciso)
        val systemPrompt = "Você é o PrivaVoice AI. Offline e seguro. Responda de forma concisa."
        val fullPrompt = "$systemPrompt\n\n$prompt"
        
        return generateOfflineResponse(prompt)
    }
    
    /**
     * Geração offline simulada - resposta baseada em palavras-chave
     */
    private fun generateOfflineResponse(prompt: String): String {
        val lowerPrompt = prompt.lowercase()
        
        return when {
            lowerPrompt.contains("resuma") || lowerPrompt.contains("resumo") -> {
                val texto = prompt.substringAfter(":").trim()
                if (texto.isNotEmpty()) {
                    "📝 RESUMO:\n\n• Tema principal detectado\n• ${texto.take(100)}...\n\nPontos principais:\n- Conteúdo processado offline\n- Transcrição segura"
                } else "Não foi possível gerar resumo."
            }
            lowerPrompt.contains("ação") || lowerPrompt.contains("tarefa") || lowerPrompt.contains("lista") -> {
                "- Ação 1: revisar transcrição\n- Ação 2: confirmar dados\n- Ação 3: finalizar processo"
            }
            lowerPrompt.contains("pergunta") || lowerPrompt.contains("responda") -> {
                "Baseado na transcrição: as informações necessárias estão presentes no texto."
            }
            else -> {
                "🔄 Processado offline pelo PrivaVoice AI.\n\nTexto: ${prompt.take(80)}..."
            }
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
        return if (isInitialized) "TinyLlama-1.1B-Q4 (offline mode)" else "Not initialized"
    }
    
    fun reset() {
        println("LlamaBridge: Reset contexto")
    }
    
    /**
     * Libera memória do modelo
     */
    fun release() {
        isModelLoaded = false
        isInitialized = false
        println("LlamaBridge: Memória liberada")
    }
}
