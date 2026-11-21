package com.optiklentera.optik_lentera

import android.media.AudioManager
import android.media.ToneGenerator
import android.os.Handler
import android.os.Looper
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val soundChannel = "optik_lentera/sound"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, soundChannel)
            .setMethodCallHandler { call, result ->
                if (call.method == "playSuccess") {
                    try {
                        val tone = ToneGenerator(AudioManager.STREAM_MUSIC, 100)
                        tone.startTone(ToneGenerator.TONE_PROP_ACK, 500)
                        Handler(Looper.getMainLooper()).postDelayed({
                            tone.release()
                        }, 700)
                        result.success(true)
                    } catch (error: Exception) {
                        result.error("SOUND_FAILED", error.message, null)
                    }
                } else {
                    result.notImplemented()
                }
            }
    }
}
