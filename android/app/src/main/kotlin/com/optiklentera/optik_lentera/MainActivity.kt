package com.optiklentera.optik_lentera

import android.content.ContentValues
import android.content.Intent
import android.content.ClipData
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
                if (call.method != "savePdf" && call.method != "sharePdf") {
                    result.notImplemented()
                    return@setMethodCallHandler
                }
                var pendingUri: android.net.Uri? = null
                try {
                    val fileName = call.argument<String>("fileName")
                        ?: "Hasil_Pemeriksaan.pdf"

                    if (call.method == "sharePdf") {
                        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) {
                            throw IllegalStateException(
                                "Berbagi PDF langsung memerlukan Android 10 atau lebih baru."
                            )
                        }
                        val projection = arrayOf(MediaStore.Downloads._ID)
                        val selection =
                            "${MediaStore.Downloads.DISPLAY_NAME} = ? AND ${MediaStore.Downloads.RELATIVE_PATH} = ?"
                        val args = arrayOf(
                            fileName,
                            Environment.DIRECTORY_DOWNLOADS + "/OPTIK LENTERA/"
                        )
                        val uri = contentResolver.query(
                            MediaStore.Downloads.EXTERNAL_CONTENT_URI,
                            projection,
                            selection,
                            args,
                            null
                        )?.use { cursor ->
                            if (cursor.moveToFirst()) {
                                val id = cursor.getLong(
                                    cursor.getColumnIndexOrThrow(MediaStore.Downloads._ID)
                                )
                                android.content.ContentUris.withAppendedId(
                                    MediaStore.Downloads.EXTERNAL_CONTENT_URI,
                                    id
                                )
                            } else null
                        } ?: throw IllegalStateException(
                            "File PDF pemeriksaan tidak ditemukan di Download/OPTIK LENTERA."
                        )

                        val sendIntent = Intent(Intent.ACTION_SEND).apply {
                            type = "application/pdf"
                            putExtra(Intent.EXTRA_STREAM, uri)
                            clipData = ClipData.newUri(contentResolver, fileName, uri)
                            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                        }
                        startActivity(
                            Intent.createChooser(sendIntent, "Kirim PDF hasil pemeriksaan")
                        )
                        result.success(true)
                        return@setMethodCallHandler
                    }

                    val bytes = call.argument<ByteArray>("bytes")
                        ?: throw IllegalArgumentException("Data PDF kosong")
                    if (bytes.isEmpty()) {
                        throw IllegalArgumentException("Data PDF kosong; file tidak dibuat.")
                    }

                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                        val relativePath =
                            Environment.DIRECTORY_DOWNLOADS + "/OPTIK LENTERA/"
                        val projection = arrayOf(MediaStore.Downloads._ID)
                        val selection =
                            "${MediaStore.Downloads.DISPLAY_NAME} = ? AND ${MediaStore.Downloads.RELATIVE_PATH} = ?"
                        val args = arrayOf(fileName, relativePath)

                        // Replace an older file with the same name instead of
                        // silently creating multiple copies in Downloads.
                        val existingUri = contentResolver.query(
                            MediaStore.Downloads.EXTERNAL_CONTENT_URI,
                            projection,
                            selection,
                            args,
                            null
                        )?.use { cursor ->
                            if (cursor.moveToFirst()) {
                                val id = cursor.getLong(
                                    cursor.getColumnIndexOrThrow(MediaStore.Downloads._ID)
                                )
                                android.content.ContentUris.withAppendedId(
                                    MediaStore.Downloads.EXTERNAL_CONTENT_URI,
                                    id
                                )
                            } else null
                        }

                        val uri = existingUri ?: run {
                            val values = ContentValues().apply {
                                put(MediaStore.Downloads.DISPLAY_NAME, fileName)
                                put(MediaStore.Downloads.MIME_TYPE, "application/pdf")
                                put(MediaStore.Downloads.RELATIVE_PATH, relativePath)
                                put(MediaStore.Downloads.IS_PENDING, 1)
                            }
                            contentResolver.insert(
                                MediaStore.Downloads.EXTERNAL_CONTENT_URI,
                                values
                            ) ?: throw IllegalStateException(
                                "Android tidak bisa membuat file di Download/OPTIK LENTERA."
                            ).also { }
                        }
                        if (existingUri == null) pendingUri = uri

                        contentResolver.openOutputStream(uri, "wt")?.use { output ->
                            output.write(bytes)
                            output.flush()
                        } ?: throw IllegalStateException(
                            "Android tidak bisa membuka file PDF untuk ditulis."
                        )

                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q && pendingUri != null) {
                            val publish = ContentValues().apply {
                                put(MediaStore.Downloads.IS_PENDING, 0)
                            }
                            val updated = contentResolver.update(uri, publish, null, null)
                            if (updated <= 0) {
                                throw IllegalStateException(
                                    "PDF sudah ditulis tetapi gagal dipublikasikan di folder Download."
                                )
                            }
                            pendingUri = null
                        }

                        val sizeProjection = arrayOf(MediaStore.Downloads.SIZE)
                        val actualSize = contentResolver.query(
                            uri, sizeProjection, null, null, null
                        )?.use { cursor ->
                            if (cursor.moveToFirst()) {
                                cursor.getLong(
                                    cursor.getColumnIndexOrThrow(MediaStore.Downloads.SIZE)
                                )
                            } else -1L
                        } ?: -1L
                        if (actualSize != bytes.size.toLong()) {
                            throw IllegalStateException(
                                "Ukuran PDF tidak cocok setelah disimpan (terbaca $actualSize dari ${bytes.size} byte)."
                            )
                        }
                        result.success("Download/OPTIK LENTERA/$fileName")
                    } else {
                        val base = getExternalFilesDir(Environment.DIRECTORY_DOWNLOADS)
                            ?: throw IllegalStateException(
                                "Penyimpanan Download aplikasi tidak tersedia."
                            )
                        val folder = File(base, "OPTIK LENTERA")
                        if (!folder.exists() && !folder.mkdirs()) {
                            throw IllegalStateException(
                                "Folder penyimpanan PDF tidak bisa dibuat."
                            )
                        }
                        val file = File(folder, fileName)
                        FileOutputStream(file).use { output ->
                            output.write(bytes)
                            output.flush()
                        }
                        if (!file.exists() || file.length() != bytes.size.toLong()) {
                            throw IllegalStateException(
                                "PDF gagal diverifikasi setelah ditulis ke penyimpanan."
                            )
                        }
                        result.success(file.absolutePath)
                    }
                } catch (error: Exception) {
                    // Do not leave an incomplete MediaStore item hidden as pending.
                    pendingUri?.let {
                        try {
                            contentResolver.delete(it, null, null)
                        } catch (_: Exception) {
                        }
                    }
                    result.error("PDF_SAVE_FAILED", error.message, null)
                }
            }
    }
}
