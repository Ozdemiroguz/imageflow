package com.oguzhan.imageflow

import android.content.ActivityNotFoundException
import android.content.Context
import android.content.Intent
import androidx.core.content.FileProvider
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File

class PdfExternalOpenHandler : FlutterPlugin, MethodChannel.MethodCallHandler {
    private lateinit var context: Context
    private lateinit var channel: MethodChannel

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        context = binding.applicationContext
        channel = MethodChannel(binding.binaryMessenger, "com.oguzhan.imageflow/pdf_external")
        channel.setMethodCallHandler(this)
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "openPdf" -> openPdf(call, result)
            else -> result.notImplemented()
        }
    }

    private fun openPdf(call: MethodCall, result: MethodChannel.Result) {
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

        try {
            val uri = FileProvider.getUriForFile(
                context,
                "${context.packageName}.fileprovider",
                file,
            )

            val intent = Intent(Intent.ACTION_VIEW).apply {
                setDataAndType(uri, "application/pdf")
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
            }

            if (intent.resolveActivity(context.packageManager) == null) {
                result.error(
                    "PDF_APP_NOT_FOUND",
                    "No external PDF viewer found on device.",
                    null,
                )
                return
            }

            context.startActivity(intent)
            result.success(true)
        } catch (e: IllegalArgumentException) {
            result.error("INVALID_PATH", e.message, null)
        } catch (e: ActivityNotFoundException) {
            result.error("PDF_APP_NOT_FOUND", e.message, null)
        } catch (e: Exception) {
            result.error("OPEN_FAILED", e.message, null)
        }
    }
}
