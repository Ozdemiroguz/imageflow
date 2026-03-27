package com.oguzhan.imageflow

import android.graphics.Bitmap
import android.graphics.Color
import android.graphics.pdf.PdfRenderer
import android.os.Handler
import android.os.Looper
import android.os.ParcelFileDescriptor
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayOutputStream
import java.io.File
import java.util.concurrent.Executors
import kotlin.math.max

class PdfRasterizeHandler : FlutterPlugin, MethodChannel.MethodCallHandler {
    private lateinit var channel: MethodChannel
    private val mainHandler = Handler(Looper.getMainLooper())
    private val ioExecutor = Executors.newSingleThreadExecutor()

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel = MethodChannel(binding.binaryMessenger, "com.oguzhan.imageflow/pdf_raster")
        channel.setMethodCallHandler(this)
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
        ioExecutor.shutdown()
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "rasterizePdf" -> rasterizePdf(call, result)
            else -> result.notImplemented()
        }
    }

    private fun rasterizePdf(call: MethodCall, result: MethodChannel.Result) {
        val path = call.argument<String>("path")
        if (path.isNullOrBlank()) {
            result.error("INVALID_ARGS", "path required", null)
            return
        }

        val file = File(path)
        if (!file.exists()) {
            result.error("FILE_NOT_FOUND", "PDF file could not be found.", null)
            return
        }

        val dpi = call.argument<Double>("dpi") ?: 144.0
        val scale = (dpi / 72.0).coerceAtLeast(1.0)

        ioExecutor.execute {
            try {
                val pages = mutableListOf<ByteArray>()
                ParcelFileDescriptor.open(file, ParcelFileDescriptor.MODE_READ_ONLY).use { fd ->
                    PdfRenderer(fd).use { renderer ->
                        for (pageIndex in 0 until renderer.pageCount) {
                            renderer.openPage(pageIndex).use { page ->
                                val width = max((page.width * scale).toInt(), 1)
                                val height = max((page.height * scale).toInt(), 1)

                                val bitmap = Bitmap.createBitmap(
                                    width,
                                    height,
                                    Bitmap.Config.ARGB_8888,
                                )
                                bitmap.eraseColor(Color.WHITE)
                                page.render(
                                    bitmap,
                                    null,
                                    null,
                                    PdfRenderer.Page.RENDER_MODE_FOR_DISPLAY,
                                )

                                val output = ByteArrayOutputStream()
                                bitmap.compress(Bitmap.CompressFormat.PNG, 100, output)
                                pages.add(output.toByteArray())
                                bitmap.recycle()
                            }
                        }
                    }
                }
                postSuccess(result, pages)
            } catch (e: Exception) {
                postError(result, "RASTER_FAILED", e.message)
            }
        }
    }

    private fun postSuccess(result: MethodChannel.Result, pages: List<ByteArray>) {
        mainHandler.post {
            result.success(pages)
        }
    }

    private fun postError(result: MethodChannel.Result, code: String, message: String?) {
        mainHandler.post {
            result.error(code, message, null)
        }
    }
}
