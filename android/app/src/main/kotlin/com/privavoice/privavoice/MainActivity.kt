package com.privavoice.privavoice

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        // Register Recording Method Channel
        RecordingMethodChannel().registerWith(flutterEngine, this)
        
        // Register Whisper Method Channel - using stub
        val whisperChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "com.privavoice/whisper"
        )
        // Whisper stub - não registra handler real
    }
}
