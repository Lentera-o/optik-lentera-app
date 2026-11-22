package com.optiklentera.optik_lentera

import android.content.ContentValues
import android.media.AudioManager
import android.media.ToneGenerator
import android.os.Build
import android.os.Environment
import android.os.Handler
import android.os.Looper
import android.provider.MediaStore
import java.io.File
import java.io.FileOutputStream
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val soundChannel = "optik_lentera/sound"
    private val pdfChannel = "optik_lentera/pdf_save"

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

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, pdfChannel)
            .setMethodCallHandler { call, result ->
                if (call.method != "savePdf") {
                    result.notImplemented()
                    return@setMethodCallHandler
                }
                try {
                    val fileName = call.argument<String>("fileName") ?: "Hasil_Pemeriksaan.pdf"
                    val bytes = call.argument<ByteArray>("bytes")
                        ?: throw IllegalArgumentException("Data PDF kosong")
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                        val values = ContentValues().apply {
                            put(MediaStore.Downloads.DISPLAY_NAME, fileName)
                            put(MediaStore.Downloads.MIME_TYPE, "application/pdf")
                            put(MediaStore.Downloads.RELATIVE_PATH, Environment.DIRECTORY_DOWNLOADS + "/OPTIK LENTERA")
                            put(MediaStore.Downloads.IS_PENDING, 1)
                        }
                        val uri = contentResolver.insert(MediaStore.Downloads.EXTERNAL_CONTENT_URI, values)
                            ?: throw IllegalStateException("Tidak bisa membuat file PDF")
                        contentResolver.openOutputStream(uri)?.use { it.write(bytes) }
                            ?: throw IllegalStateException("Tidak bisa menulis file PDF")
                        values.clear()
                        values.put(MediaStore.Downloads.IS_PENDING, 0)
                        contentResolver.update(uri, values, null, null)
                        result.success(uri.toString())
                    } else {
                        val folder = File(getExternalFilesDir(Environment.DIRECTORY_DOWNLOADS), "OPTIK LENTERA")
                        if (!folder.exists()) folder.mkdirs()
                        val file = File(folder, fileName)
                        FileOutputStream(file).use { it.write(bytes) }
                        result.success(file.absolutePath)
                    }
                } catch (error: Exception) {
                    result.error("PDF_SAVE_FAILED", error.message, null)
                }
            }
    }
}
