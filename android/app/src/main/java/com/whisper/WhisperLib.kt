package com.whisper

/**
 * Stub for native Whisper library
 * Full implementation requires libwhisper.so
 */
object WhisperLib {
    
    init {
        try {
            System.loadLibrary("whisper")
            println("Whisper: ✅ libwhisper.so loaded")
        } catch (e: UnsatisfiedLinkError) {
            println("Whisper: ⚠️ libwhisper.so not found - using stub")
        }
    }
    
    /**
     * Initialize Whisper context from file
     */
    fun initFromFile(path: String): Long = 0
    
    /**
     * Free Whisper context
     */
    fun free(ctx: Long) {}
    
    /**
     * Run full transcription
     */
    fun full(ctx: Long, audioData: FloatArray): Int = 0
    
    /**
     * Get number of segments
     */
    fun getNSegments(ctx: Long): Int = 0
    
    /**
     * Get segment text
     */
    fun getSegmentText(ctx: Long, indexSegment: Int): String = ""
}
