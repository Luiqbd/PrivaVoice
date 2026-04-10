package com.privavoice.privavoice

import android.app.ActivityManager
import android.content.Context
import io.github.ljcamargo.llamacpp.LlamaContext
import io.github.ljcamargo.llamacpp.LlamaHelper
import java.io.File

/**
 * Llama Bridge - Usa io.github.ljcamargo:llamacpp-kotlin:0.2.0
 */
class LlamaBridge(private val context: Context) {
    
    private var llamaContext: LlamaContext? = null
    private var modelPath: String = ""
    private var nCtx: Int = 2048
    private var nThreads: Int = 4
    
    var isInitialized: Boolean = false
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
    
    private fun logMemory(tag: String) {
        try {
            val activityManager = context.getSystemService(Context.ACTIVITY_SERVICE) as ActivityManager
            val memInfo = ActivityManager.MemoryInfo()
            activityManager.getMemoryInfo(memInfo)
            println("LlamaBridge [$tag]: Memória livre = ${memInfo.availMem / 1024 / 1024} MB")
        } catch (e: Exception) {
            println("LlamaBridge [$tag]: Erro ao obter memória")
        }
    }
    
    fun initialize(modelPath: String, nCtx: Int = 2048, nThreads: Int = 4): Boolean {
        logMemory("ANTES")
        
        return try {
            this.modelPath = modelPath
            this.nCtx = nCtx
            this.nThreads = nThreads
            
            val modelFile = File(modelPath)
            if (!modelFile.exists()) {
                println("LlamaBridge: Arquivo não encontrado: $modelPath")
                return false
            }
            println("LlamaBridge: Modelo = ${modelFile.length() / 1024 / 1024} MB")
            
            llamaContext = LlamaHelper.load(modelPath, nCtx, nThreads)
            isInitialized = llamaContext != null
            logMemory("DEPOIS")
            println("LlamaBridge: Carregado = $isInitialized")
            isInitialized
        } catch (e: Exception) {
            println("LlamaBridge: Erro: ${e.message}")
            logMemory("ERRO")
            isInitialized = false
            false
        }
    }
    
    fun generate(prompt: String, maxTokens: Int = 200): String {
        if (!isInitialized) throw IllegalStateException("Not initialized")
        
        val fullPrompt = "Você é o PrivaVoice AI. Offline e seguro.\n\n$prompt"
        
        return try {
            llamaContext?.predict(fullPrompt) ?: ""
        } catch (e: Exception) {
            "Erro: ${e.message}"
        }
    }
    
    fun summarize(transcription: String): String {
        val prompt = "Resuma os pontos principais desta transcrição de forma profissional e concisa:\n\n$transcription"
        return generate(prompt, 200)
    }
    
    fun extractActionItems(transcription: String): List<String> {
        val prompt = "Liste as ações mencionadas:\n\n$transcription"
        val result = generate(prompt, 100)
        return result.split("\n").filter { it.isNotBlank() && it.contains("- ") }
    }
    
    fun answerQuestion(transcription: String, question: String): String {
        val prompt = "Com base no texto:\n$transcription\n\nPergunta: $question"
        return generate(prompt, 150)
    }
    
    fun getModelInfo(): String = if (isInitialized) "TinyLlama-1.1B-Q4" else "Not loaded"
    
    fun reset() = llamaContext?.stop()
    
    fun release() {
        try {
            llamaContext?.stop()
            llamaContext?.release()
        } catch (e: Exception) {
            println("LlamaBridge: Erro ao liberar: ${e.message}")
        }
        llamaContext = null
        isInitialized = false
        logMemory("APÓS release")
    }
}
