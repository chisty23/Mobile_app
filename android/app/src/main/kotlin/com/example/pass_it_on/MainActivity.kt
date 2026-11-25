package com.example.pass_it_on

import android.app.Activity
import android.content.Intent
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.net.Uri
import android.util.Base64
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayOutputStream
import kotlin.concurrent.thread
import kotlin.math.max
import kotlin.math.roundToInt

class MainActivity : FlutterActivity() {
    companion object {
        private const val CHANNEL = "passiton/media_picker"
        private const val PICK_IMAGES_REQUEST = 40821
    }

    private var pendingResult: MethodChannel.Result? = null
    private var maxCount: Int = 3

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                if (call.method == "pickCompressedImages") {
                    if (pendingResult != null) {
                        result.error("BUSY", "Image picker already open", null)
                        return@setMethodCallHandler
                    }
                    maxCount = (call.argument<Int>("maxCount") ?: 3).coerceIn(1, 5)
                    pendingResult = result
                    val intent = Intent(Intent.ACTION_GET_CONTENT).apply {
                        type = "image/*"
                        putExtra(Intent.EXTRA_ALLOW_MULTIPLE, maxCount > 1)
                        addCategory(Intent.CATEGORY_OPENABLE)
                    }
                    startActivityForResult(
                        Intent.createChooser(intent, "Select listing photos"),
                        PICK_IMAGES_REQUEST
                    )
                } else {
                    result.notImplemented()
                }
            }
    }

    @Deprecated("Deprecated in Java")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode != PICK_IMAGES_REQUEST) return

        val callback = pendingResult
        pendingResult = null
        if (callback == null) return

        if (resultCode != Activity.RESULT_OK || data == null) {
            callback.success(emptyList<String>())
            return
        }

        val uris = mutableListOf<Uri>()
        val clip = data.clipData
        if (clip != null) {
            val count = minOf(clip.itemCount, maxCount)
            for (i in 0 until count) {
                clip.getItemAt(i)?.uri?.let { uris.add(it) }
            }
        } else {
            data.data?.let { uris.add(it) }
        }

        thread {
            val encoded = uris.mapNotNull { compressUriToDataUrl(it) }
            runOnUiThread { callback.success(encoded) }
        }
    }

    private fun compressUriToDataUrl(uri: Uri): String? {
        return try {
            val bounds = BitmapFactory.Options().apply { inJustDecodeBounds = true }
            contentResolver.openInputStream(uri)?.use { stream ->
                BitmapFactory.decodeStream(stream, null, bounds)
            }
            val longest = max(bounds.outWidth, bounds.outHeight)
            if (longest <= 0) return null

            var sample = 1
            while (longest / sample > 1280) {
                sample *= 2
            }

            val decodeOpts = BitmapFactory.Options().apply { inSampleSize = sample }
            val original = contentResolver.openInputStream(uri)?.use { stream ->
                BitmapFactory.decodeStream(stream, null, decodeOpts)
            } ?: return null

            val maxDim = 800
            val w = original.width
            val h = original.height
            val scaled: Bitmap = if (w > maxDim || h > maxDim) {
                val ratio = maxDim.toFloat() / max(w, h).toFloat()
                Bitmap.createScaledBitmap(
                    original,
                    (w * ratio).roundToInt().coerceAtLeast(1),
                    (h * ratio).roundToInt().coerceAtLeast(1),
                    true
                )
            } else {
                original
            }

            val out = ByteArrayOutputStream()
            scaled.compress(Bitmap.CompressFormat.JPEG, 75, out)
            if (scaled !== original) scaled.recycle()
            original.recycle()

            val b64 = Base64.encodeToString(out.toByteArray(), Base64.NO_WRAP)
            "data:image/jpeg;base64,$b64"
        } catch (_: Exception) {
            null
        }
    }
}
