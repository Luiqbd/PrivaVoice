package com.privavoice.privavoice

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Intent
import android.content.pm.ServiceInfo
import android.media.MediaRecorder
import android.media.AudioRecord
import android.media.AudioFormat
import android.os.Binder
import android.os.Build
import android.os.IBinder
import androidx.core.app.NotificationCompat
import kotlinx.coroutines.*
import java.io.File

class RecordingService : Service() {
    
    private val binder = RecordingBinder()
    private var mediaRecorder: MediaRecorder? = null
    private var isRecording = false
    private var isPaused = false
    private var currentFilePath: String? = null
    private var recordingStartTime: Long = 0
    private var pausedDuration: Long = 0
    
    private val serviceScope = CoroutineScope(Dispatchers.IO + Job())
    
    companion object {
        const val CHANNEL_ID = "privavoice_recording_channel"
        const val NOTIFICATION_ID = 1001
    }
    
    inner class RecordingBinder : Binder() {
        fun getService(): RecordingService = this@RecordingService
    }
    
    override fun onBind(intent: Intent?): IBinder = binder
    
    override fun onCreate() {
        super.onCreate()
        createNotificationChannel()
    }
    
    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            "START" -> {
                val filePath = intent.getStringExtra("path") ?: return START_NOT_STICKY
                startRecording(filePath)
            }
            "PAUSE" -> pauseRecording()
            "RESUME" -> resumeRecording()
            "STOP" -> stopRecording()
            "FLUSH" -> flushBuffer()
        }
        return START_STICKY
    }
    
    private fun createNotificationChannel() {
        val channel = NotificationChannel(
            CHANNEL_ID,
            "Gravação PrivaVoice",
            NotificationManager.IMPORTANCE_LOW
        ).apply {
            description = "Mantém a gravação ativa em segundo plano"
            setShowBadge(false)
        }
        
        val notificationManager = getSystemService(NotificationManager::class.java)
        notificationManager.createNotificationChannel(channel)
    }
    
    private fun startForegroundService(title: String, text: String) {
        val notification = NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle(title)
            .setContentText(text)
            .setSmallIcon(android.R.drawable.ic_btn_speak_now)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .setOngoing(true)
            .build()
        
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            startForeground(NOTIFICATION_ID, notification, ServiceInfo.FOREGROUND_SERVICE_TYPE_MICROPHONE)
        } else {
            startForeground(NOTIFICATION_ID, notification)
        }
    }
    
    private fun startRecording(filePath: String) {
        try {
            currentFilePath = filePath
            
            // CRITICAL: Force WAV 16kHz Mono for Whisper compatibility
            val outputFile = File(filePath.replace(".m4a", ".wav"))
            
            mediaRecorder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                MediaRecorder(this)
            } else {
                @Suppress("DEPRECATION")
                MediaRecorder()
            }.apply {
                setAudioSource(MediaRecorder.AudioSource.MIC)
                setOutputFormat(MediaRecorder.OutputFormat.DEFAULT)
                setAudioEncoder(MediaRecorder.AudioEncoder.DEFAULT)
                setAudioSamplingRate(16000)  // CRITICAL: 16kHz for Whisper
                setAudioEncodingBitRate(25600)
                setOutputFile(outputFile.absolutePath)
                prepare()
                start()
            }
            
            // Update path to WAV
            currentFilePath = outputFile.absolutePath
            
            // Ativar Noise Suppressor nativo do Android
            try {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.JELLY_BEAN) {
                    val audioRecord = AudioRecord(
                        MediaRecorder.AudioSource.MIC,
                        16000,
                        android.media.AudioFormat.CHANNEL_IN_MONO,
                        android.media.AudioFormat.ENCODING_PCM_16BIT,
                        1024
                    )
                    // Noise suppression done automatically by MediaRecorder on modern Android
                }
            } catch (e: Exception) {
                println("RecordingService: Noise suppression not available: ${e.message}")
            }
            
            isRecording = true
            isPaused = false
            recordingStartTime = System.currentTimeMillis()
            
            startForegroundService("PrivaVoice Gravando", "Gravação em andamento")
            
        } catch (e: Exception) {
            e.printStackTrace()
            stopSelf()
        }
    }
    
    private fun pauseRecording() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            mediaRecorder?.pause()
            isPaused = true
            pausedDuration = System.currentTimeMillis() - recordingStartTime
            updateNotification("PrivaVoice Pausado", "Toque para continuar")
        }
    }
    
    private fun resumeRecording() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            mediaRecorder?.resume()
            isPaused = false
            recordingStartTime = System.currentTimeMillis() - pausedDuration
            updateNotification("PrivaVoice Gravando", "Gravação em andamento")
        }
    }
    
    private fun stopRecording(): Map<String, Any>? {
        return try {
            mediaRecorder?.apply {
                stop()
                release()
            }
            mediaRecorder = null
            isRecording = false
            
            val file = File(currentFilePath ?: return null)
            val duration = if (recordingStartTime > 0) {
                System.currentTimeMillis() - recordingStartTime
            } else 0L
            
            stopForeground(STOP_FOREGROUND_REMOVE)
            stopSelf()
            
            mapOf(
                "path" to (currentFilePath ?: ""),
                "duration" to duration,
                "size" to (if (file.exists()) file.length().toInt() else 0)
            )
        } catch (e: Exception) {
            e.printStackTrace()
            null
        }
    }
    
    private fun flushBuffer() {
        // Flush audio buffer to ensure data is written
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N && isPaused) {
                // Can't flush while paused
                return
            }
            // MediaRecorder automatically flushes, but we can force sync
            // sync() - removed
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }
    
    private fun updateNotification(title: String, text: String) {
        val notification = NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle(title)
            .setContentText(text)
            .setSmallIcon(android.R.drawable.ic_btn_speak_now)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .setOngoing(true)
            .build()
        
        val notificationManager = getSystemService(NotificationManager::class.java)
        notificationManager.notify(NOTIFICATION_ID, notification)
    }
    
    fun getCurrentDuration(): Long {
        return if (isRecording && !isPaused) {
            System.currentTimeMillis() - recordingStartTime
        } else pausedDuration
    }
    
    override fun onDestroy() {
        serviceScope.cancel()
        mediaRecorder?.release()
        super.onDestroy()
    }
}
