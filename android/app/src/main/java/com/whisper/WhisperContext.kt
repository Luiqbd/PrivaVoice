package com.whisper

import android.content.Context
import java.io.File

/**
 * Stub WhisperContext for offline voice transcription
 * Full implementation requires the native library and AAR
 */
class WhisperContext private constructor() {
    
    companion object {
        /**
         * Create WhisperContext from model file path
         */
        fun create(modelPath: String): WhisperContext {
            println("WhisperContext: create('$modelPath') - STUB")
            return WhisperContext()
        }
    }
    
    /**
     * Transcribe audio file and return result
     */
    fun transcribe(audioFile: File): String {
        println("WhisperContext: transcribe() - STUB returning empty")
        return ""
    }
    
    /**
     * Release resources
     */
    fun release() {
        println("WhisperContext: release() - STUB")
    }
}
