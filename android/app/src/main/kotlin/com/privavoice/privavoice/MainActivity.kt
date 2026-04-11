package com.privavoice.privavoice

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // Register Recording Method Channel
        RecordingMethodChannel().registerWith(flutterEngine, this)

        // Register Whisper Method Channel (stub)
        val whisperChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "com.privavoice/whisper"
        )
        whisperChannel.setMethodCallHandler { call, result ->
            when (call.method) {
                "initialize" -> result.success(true)
                "getModelInfo" -> result.success(mapOf("status" to "stub"))
                else -> result.notImplemented()
            }
        }
    }
}
