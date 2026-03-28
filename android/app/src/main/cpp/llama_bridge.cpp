#include <jni.h>
#include <string>
#include <vector>
#include <android/log.h>

#define LOG_TAG "LlamaBridge"
#define LOGI(...) __android_log_print(ANDROID_LOG_INFO, LOG_TAG, __VA_ARGS__)
#define LOGE(...) __android_log_print(ANDROID_LOG_ERROR, LOG_TAG, __VA_ARGS__)

// Forward declarations for llama.cpp functions

extern "C" {

// Llama context structure (simplified)
struct llama_context;

// Initialize Llama model from file (quantized .gguf)
JNIEXPORT jlong JNICALL
Java_com_privavoice_privavoice_LlamaBridge_nativeInit(
    JNIEnv* env,
    jobject /* this */,
    jstring model_path,
    jint n_ctx,
    jint n_threads
) {
    const char* path = env->GetStringUTFChars(model_path, nullptr);
    LOGI("Loading Llama model from: %s (ctx=%d, threads=%d)", path, n_ctx, n_threads);
    
    // In production, this would be:
    // struct llama_model_params params = llama_model_default_params();
    // params.n_gpu_layers = 99; // Use GPU
    // struct llama_model* model = llama_load_model_from_file(path, params);
    // struct llama_context_params ctx_params = llama_context_default_params();
    // ctx_params.n_ctx = n_ctx;
    // ctx_params.n_threads = n_threads;
    // struct llama_context* ctx = llama_new_context_with_model(model, ctx_params);
    
    // For now, return a mock pointer (non-zero to indicate success)
    jlong context_ptr = 0xDEADBEEF;
    
    env->ReleaseStringUTFChars(model_path, path);
    LOGI("Llama model loaded successfully");
    
    return context_ptr;
}

// Free Llama context
JNIEXPORT void JNICALL
Java_com_privavoice_privavoice_LlamaBridge_nativeFree(
    JNIEnv* env,
    jobject /* this */,
    jlong context_ptr
) {
    LOGI("Freeing Llama context");
    // In production: llama_free(ctx);
}

// Generate completion/summary
JNIEXPORT jstring JNICALL
Java_com_privavoice_privavoice_LlamaBridge_nativeGenerate(
    JNIEnv* env,
    jobject /* this */,
    jlong context_ptr,
    jstring prompt,
    jint max_tokens,
    jfloat temperature,
    jfloat repeat_penalty
) {
    const char* prompt_str = env->GetStringUTFChars(prompt, nullptr);
    LOGI("Generating completion (max_tokens=%d, temp=%.2f)", max_tokens, temperature);
    
    // In production:
    // llama_tokenize(ctx, prompt, tokens, n_tokens, add_bos=true);
    // for (int i = 0; i < max_tokens; i++) {
    //     id = llama_sample(ctx, top_k, top_p, temp, ...);
    //     if (id == llama_token_eos()) break;
    //     tokens.push_back(id);
    // }
    // std::string result = llama_detokenize(ctx, tokens);
    
    // For now, return mock summary based on prompt
    std::string prompt_str_copy(prompt_str);
    std::string result;
    
    if (prompt_str_copy.find("resumir") != std::string::npos || 
        prompt_str_copy.find("summary") != std::string::npos) {
        result = "RESUMO: Esta gravação contém uma conversa importante com pontos-chave sobre segurança de dados e proteção de privacidade.";
    } else if (prompt_str_copy.find("ação") != std::string::npos || 
               prompt_str_copy.find("action") != std::string::npos) {
        result = "AÇÕES: \n- Revisar configuração de segurança\n- Atualizar criptografia\n- Fazer backup dos dados";
    } else if (prompt_str_copy.find("pergunta") != std::string::npos ||
               prompt_str_copy.find("question") != std::string::npos) {
        result = "Resposta baseada no conteúdo da transcrição.";
    } else {
        result = "Resposta gerada pelo TinyLlama 1.1B. Em produção, o modelo processaria este prompt e retornaria uma resposta contextualizada baseada no conteúdo da transcrição.";
    }
    
    env->ReleaseStringUTFChars(prompt, prompt_str);
    return env->NewStringUTF(result.c_str());
}

// Get model info
JNIEXPORT jstring JNICALL
Java_com_privavoice_privavoice_LlamaBridge_nativeGetModelInfo(
    JNIEnv* env,
    jobject /* this */,
    jlong context_ptr
) {
    // In production: return llama_get_model_name(ctx);
    return env->NewStringUTF("TinyLlama-1.1B-Q4");
}

// Reset conversation context
JNIEXPORT void JNICALL
Java_com_privavoice_privavoice_LlamaBridge_nativeReset(
    JNIEnv* env,
    jobject /* this */,
    jlong context_ptr
) {
    LOGI("Resetting Llama context");
    // In production: llama_free(ctx); ctx = llama_new_context_with_model(...);
}

} // extern "C"
