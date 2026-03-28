package com.privavoice.privavoice

import android.content.Context

/**
 * Whisper Bridge - JNI interface to whisper.cpp
 * Handles on-device speech-to-text with GPU acceleration
 */
class WhisperBridge private constructor() {
    
    private var nativeContext: Long = 0
    var isInitialized: Boolean = false
        private set
    
    companion object {
        @Volatile
        private var instance: WhisperBridge? = null
        
        fun getInstance(): WhisperBridge {
            return instance ?: synchronized(this) {
                instance ?: WhisperBridge().also { instance = it }
            }
        }
    }
    
    /**
     * Initialize Whisper model from file
     * @param modelPath Path to GGML model file (e.g., whisper-base.bin)
     */
    fun initialize(modelPath: String): Boolean {
        return try {
            nativeContext = nativeInit(modelPath)
            isInitialized = nativeContext != 0L
            isInitialized
        } catch (e: Exception) {
            isInitialized = false
            false
        }
    }
    
    /**
     * Transcribe audio file to text
     * @param audioPath Path to audio file (M4A, WAV, etc.)
     * @param maxContext Maximum context tokens (-1 for default)
     * @param maxLen Maximum length of transcription (0 for no limit)
     * @return Transcribed text
     */
    fun transcribe(audioPath: String, maxContext: Int = -1, maxLen: Int = 0): String {
        if (!isInitialized) {
            throw IllegalStateException("Whisper not initialized. Call initialize() first.")
        }
        
        return try {
            nativeTranscribe(nativeContext, audioPath, maxContext, maxLen) ?: ""
        } catch (e: Exception) {
            "Erro na transcrição: ${e.message}"
        }
    }
    
    /**
     * Get number of text segments
     */
    fun getSegmentCount(): Int {
        return if (isInitialized) {
            try {
                nativeGetSegmentCount(nativeContext)
            } catch (e: Exception) {
                0
            }
        } else 0
    }
    
    /**
     * Get text for specific segment
     */
    fun getSegmentText(segmentIndex: Int): String {
        return if (isInitialized) {
            try {
                nativeGetSegmentText(nativeContext, segmentIndex) ?: ""
            } catch (e: Exception) {
                ""
            }
        } else ""
    }
    
    /**
     * Get word timestamps for a segment
     * Returns list of [word, start_ms, end_ms] triplets
     */
    fun getWordTimestamps(segmentIndex: Int): List<String> {
        return if (isInitialized) {
            try {
                nativeGetWordTimestamps(nativeContext, segmentIndex)?.toList() ?: emptyList()
            } catch (e: Exception) {
                emptyList()
            }
        } else emptyList()
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
    private external fun nativeInit(modelPath: String): Long
    private external fun nativeFree(contextPtr: Long)
    private external fun nativeTranscribe(contextPtr: Long, audioPath: String, maxContext: Int, maxLen: Int): String?
    private external fun nativeGetSegmentCount(contextPtr: Long): Int
    private external fun nativeGetSegmentText(contextPtr: Long, segmentIndex: Int): String?
    private external fun nativeGetWordTimestamps(contextPtr: Long, segmentIndex: Int): Array<String>?
    
    init {
        System.loadLibrary("whisper")
    }
}
