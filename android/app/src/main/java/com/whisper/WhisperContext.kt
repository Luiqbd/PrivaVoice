package com.whisper

import java.io.File

/**
 * WhisperContext stub - requires native library (.so)
 * For full implementation:
 * 1. Download AAR from JitPack when available, OR
 * 2. Build whisper-android from source: https://github.com/gouh/whisper-android
 */
class WhisperContext private constructor() {
    private var initialized = false
    
    companion object {
        fun create(modelPath: String): WhisperContext {
            println("WhisperContext: STUB - model='$modelPath'")
            return WhisperContext()
        }
    }
    
    fun transcribe(audioFile: File): String {
        println("WhisperContext: STUB transcribe - returning empty")
        return ""
    }
    
    fun release() {
        println("WhisperContext: STUB released")
    }
}
