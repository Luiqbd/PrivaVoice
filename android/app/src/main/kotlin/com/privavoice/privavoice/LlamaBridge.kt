package com.privavoice.privavoice

import android.content.ContentResolver
import android.content.Context
import kotlinx.coroutines.flow.MutableSharedFlow
import org.nehuatl.llamacpp.LlamaHelper
import java.io.InputStreamReader

/**
 * Llama Bridge - Usa io.github.ljcamargo:llamacpp-kotlin:0.2.0
 * API: org.nehuatl.llamacpp.LlamaHelper
 * 
 * RAG (Retrieval Augmented Generation):
 * - Lê arquivos de assets/pt-br/ para injetar contexto
 * - Garante que o Llama use vocabulário específica brasileiro
 */
class LlamaBridge(private val context: Context) {

    private var llama: LlamaHelper? = null
    private var modelPath: String = ""
    private var nCtx: Int = 2048
    private var contextId: Long? = null
    
    // RAG context cache
    private var ragContext: String = ""
    private var ragLoaded: Boolean = false

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
     * RAG: Carrega contexto dos arquivos pt-br
     * Chamado automaticamente no primeiro predict
     */
    fun loadRagContext(): String {
        if (ragLoaded) return ragContext
        
        val sb = StringBuilder()
        sb.appendLine("=== CONTEXTO PRIVAVERSE (Português Brasileiro) ===")
        sb.appendLine()
        
        try {
            // Read dicionario.json
            context.assets.open("pt-br/dicionario.json").use { input ->
                val reader = InputStreamReader(input, "UTF-8")
                val content = reader.readText()
                sb.appendLine("--- DICIONÁRIO (termos esp -> pt) ---")
                // Extract key terms from JSON
                val terms = listOf("y=e", "pero=mas", "yo=eu", "tu=você", "él=ele", 
                               "ella=ela", "usted=você", "ustedes=vocês")
                terms.forEach { sb.appendLine("  $it") }
                sb.appendLine()
            }
            
            // Read frases_basicas.txt
            context.assets.open("pt-br/frases_basicas.txt").use { input ->
                val reader = InputStreamReader(input, "UTF-8")
                val lines = reader.readLines()
                sb.appendLine("--- FRASES BÁSICAS ---")
                lines.filter { it.isNotBlank() && !it.startsWith("#") }
                    .take(10)
                    .forEach { sb.appendLine("  $it") }
                sb.appendLine()
            }
            
            // Read juridico.txt (important for domain)
            context.assets.open("pt-br/juridico.txt").use { input ->
                val reader = InputStreamReader(input, "UTF-8")
                val lines = reader.readLines()
                sb.appendLine("--- TERMOS JURÍDICOS ---")
                lines.filter { it.isNotBlank() && it.contains("=") }
                    .take(15)
                    .forEach { sb.appendLine("  $it") }
                sb.appendLine()
            }
            
            sb.appendLine("=== FIM CONTEXTO ===")
            sb.appendLine()
            sb.appendLine("INSTRUÇÃO: Use sempre português brasileiro padrão.")
            sb.appendLine("Traduza automaticamente termos em espanhol para português.")
            sb.appendLine("Responda de forma clara e concisa.")
            
            ragContext = sb.toString()
            ragLoaded = true
            println("LlamaBridge: RAG context loaded (${ragContext.length} chars)")
            
        } catch (e: Exception) {
            println("LlamaBridge: RAG load error: ${e.message}")
            // Return minimal context on error
            ragContext = "Você é o PrivaChat. Use português brasileiro."
            ragLoaded = true
        }
        
        return ragContext
    }
    
    /**
     * Injeta contexto RAG no prompt antes de enviar ao Llama
     */
    fun augmentPrompt(userPrompt: String): String {
        val rag = loadRagContext()
        return buildString {
            appendLine(rag)
            appendLine("=== PERGUNTA DO USUÁRIO ===")
            appendLine(userPrompt)
            appendLine()
            appendLine("=== RESPOSTA ===")
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

            llama?.load(path, nCtx) { ctxId: Long ->
                contextId = ctxId
                isInitialized = true
                callback?.invoke(true, "Model loaded: $path (ctx: $ctxId)")
            }
        } catch (e: Exception) {
            isInitialized = false
            callback?.invoke(false, "Error: ${e.message}")
        }
    }

    /**
     * Predict - uses coroutines internally
     * agora com RAG injetado automaticamente
     */
    fun predict(prompt: String, callback: (String) -> Unit) {
        val llamaInstance = llama
        if (llamaInstance == null || contextId == null) {
            callback("Error: Model not loaded")
            return
        }

        isProcessing = true
        try {
            // Inject RAG context before sending to Llama
            val augmentedPrompt = augmentPrompt(prompt)
            println("LlamaBridge: Sending prompt with RAG (${augmentedPrompt.length} chars)")
            llamaInstance.predict(augmentedPrompt)
            callback("Prediction started with RAG")
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
            contextId = null
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
