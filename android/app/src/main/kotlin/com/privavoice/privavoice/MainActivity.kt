package com.privavoice.privavoice

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // Register Recording Method Channel
        RecordingMethodChannel().registerWith(flutterEngine, this)

        // TODO: Register Whisper Method Channel when implementation is ready
    }
}
