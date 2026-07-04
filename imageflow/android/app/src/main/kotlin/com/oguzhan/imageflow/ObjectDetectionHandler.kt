package com.oguzhan.imageflow

import android.content.Context
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.ImageFormat
import android.graphics.Matrix
import android.graphics.Rect
import android.graphics.YuvImage
import android.os.Handler
import android.os.Looper
import android.util.Log
import androidx.exifinterface.media.ExifInterface
import com.google.mediapipe.framework.image.BitmapImageBuilder
import com.google.mediapipe.tasks.core.BaseOptions
import com.google.mediapipe.tasks.vision.core.RunningMode
import com.google.mediapipe.tasks.vision.objectdetector.ObjectDetector
import com.google.mediapipe.tasks.vision.objectdetector.ObjectDetector.ObjectDetectorOptions
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import java.io.ByteArrayOutputStream
import java.io.File
import java.util.concurrent.Executors

/// Method-channel handler for realtime + still-image object detection.
///
/// Backed by MediaPipe Tasks ObjectDetector with an EfficientDet-Lite0 model
/// (COCO-80, Apache-2.0). The model asset lives at
/// `android/app/src/main/assets/[MODEL_ASSET]`.
///
/// Graceful degradation: if the model asset is missing (not yet bundled) the
/// detector stays null and every call returns "no objects" (empty / null) so
/// the rest of the app keeps working — it never errors just because objects
/// are unavailable. This mirrors the Dart-side contract:
///   - file path  → list (possibly empty)
///   - frame path → list, or null when busy / degraded (drop-frame)
class ObjectDetectionHandler : FlutterPlugin, MethodCallHandler {

    private lateinit var channel: MethodChannel
    private var appContext: Context? = null
    private val executor = Executors.newSingleThreadExecutor()
    private val mainHandler = Handler(Looper.getMainLooper())

    @Volatile private var frameBusy = false

    // Two detectors: one in IMAGE mode for still files, one in VIDEO mode for
    // the camera stream (VIDEO mode enables MediaPipe's cross-frame tracking).
    private var imageDetector: ObjectDetector? = null
    private var videoDetector: ObjectDetector? = null
    private var frameTimestampMs = 0L

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        appContext = binding.applicationContext
        channel = MethodChannel(binding.binaryMessenger, CHANNEL)
        channel.setMethodCallHandler(this)
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
        imageDetector?.close()
        videoDetector?.close()
        imageDetector = null
        videoDetector = null
        appContext = null
    }

    override fun onMethodCall(call: MethodCall, result: Result) {
        when (call.method) {
            "detectObjects" -> handleFile(call, result)
            "detectObjectsFromFrame" -> handleFrame(call, result)
            else -> result.notImplemented()
        }
    }

    // -------------------------------------------------------------------------
    // Still image (file path)
    // -------------------------------------------------------------------------

    private fun handleFile(call: MethodCall, result: Result) {
        val imagePath = call.argument<String>("imagePath")
        if (imagePath == null) {
            result.error("INVALID_ARGS", "imagePath required", null)
            return
        }
        val detector = imageDetectorOrNull()
        if (detector == null) {
            // Degraded (no model) is a valid "no objects" outcome, not an error.
            result.success(emptyList<Map<String, Any>>())
            return
        }
        executor.execute {
            try {
                val file = File(imagePath)
                if (!file.exists()) {
                    mainHandler.post { result.success(emptyList<Map<String, Any>>()) }
                    return@execute
                }
                val bitmap = decodeBitmapWithOrientation(file)
                if (bitmap == null) {
                    mainHandler.post { result.success(emptyList<Map<String, Any>>()) }
                    return@execute
                }
                val mpImage = BitmapImageBuilder(bitmap).build()
                val detection = detector.detect(mpImage)
                val objects = mapResults(detection, bitmap.width, bitmap.height)
                bitmap.recycle()
                mainHandler.post { result.success(objects) }
            } catch (e: Exception) {
                Log.e(TAG, "File object detection failed", e)
                mainHandler.post { result.error("DETECTION_ERROR", e.message, null) }
            }
        }
    }

    // -------------------------------------------------------------------------
    // Realtime frame (drop-frame hot path)
    // -------------------------------------------------------------------------

    private fun handleFrame(call: MethodCall, result: Result) {
        val width = call.argument<Int>("width")
        val height = call.argument<Int>("height")
        val rotation = call.argument<Int>("rotation") ?: 0
        val format = call.argument<String>("format") ?: "bgra"
        if (width == null || height == null) {
            result.error("INVALID_ARGS", "width/height required", null)
            return
        }
        val detector = videoDetectorOrNull()
        if (detector == null || frameBusy) {
            // Degraded or already busy → drop this frame.
            result.success(emptyList<Map<String, Any>>())
            return
        }
        frameBusy = true
        executor.execute {
            try {
                val bitmap = when (format) {
                    "yuv420" -> {
                        val yBytes = call.argument<ByteArray>("yBytes")
                        val uBytes = call.argument<ByteArray>("uBytes")
                        val vBytes = call.argument<ByteArray>("vBytes")
                        val yRowStride = call.argument<Int>("yRowStride") ?: width
                        val uvRowStride = call.argument<Int>("uvRowStride") ?: width
                        val uvPixelStride = call.argument<Int>("uvPixelStride") ?: 1
                        if (yBytes == null || uBytes == null || vBytes == null) {
                            null
                        } else {
                            yuvToBitmap(
                                yBytes, uBytes, vBytes, width, height,
                                yRowStride, uvRowStride, uvPixelStride,
                            )
                        }
                    }
                    else -> {
                        val bytes = call.argument<ByteArray>("bytes")
                        val bytesPerRow = call.argument<Int>("bytesPerRow") ?: (width * 4)
                        if (bytes == null) null
                        else bgraToBitmap(bytes, width, height, bytesPerRow)
                    }
                }

                if (bitmap == null) {
                    mainHandler.post { result.success(emptyList<Map<String, Any>>()) }
                    return@execute
                }

                val oriented = rotateBitmap(bitmap, rotation)
                val mpImage = BitmapImageBuilder(oriented).build()
                // VIDEO mode requires a monotonically increasing timestamp.
                frameTimestampMs += 1
                val detection = detector.detectForVideo(mpImage, frameTimestampMs)
                val objects = mapResults(detection, oriented.width, oriented.height)
                oriented.recycle()
                mainHandler.post { result.success(objects) }
            } catch (e: Exception) {
                Log.w(TAG, "Frame object detection failed", e)
                mainHandler.post { result.success(emptyList<Map<String, Any>>()) }
            } finally {
                frameBusy = false
            }
        }
    }

    // -------------------------------------------------------------------------
    // Detector lazy init (per running mode)
    // -------------------------------------------------------------------------

    private fun imageDetectorOrNull(): ObjectDetector? {
        imageDetector?.let { return it }
        imageDetector = buildDetector(RunningMode.IMAGE)
        return imageDetector
    }

    private fun videoDetectorOrNull(): ObjectDetector? {
        videoDetector?.let { return it }
        videoDetector = buildDetector(RunningMode.VIDEO)
        return videoDetector
    }

    private fun buildDetector(mode: RunningMode): ObjectDetector? {
        val context = appContext ?: return null
        if (!assetExists(context, MODEL_ASSET)) {
            Log.w(TAG, "Object detection model '$MODEL_ASSET' not bundled; degrading to no-op.")
            return null
        }
        return try {
            val baseOptions = BaseOptions.builder()
                .setModelAssetPath(MODEL_ASSET)
                .build()
            val options = ObjectDetectorOptions.builder()
                .setBaseOptions(baseOptions)
                .setRunningMode(mode)
                .setScoreThreshold(SCORE_THRESHOLD)
                .setMaxResults(MAX_RESULTS)
                .build()
            ObjectDetector.createFromOptions(context, options)
        } catch (e: Exception) {
            Log.e(TAG, "Failed to create ObjectDetector ($mode)", e)
            null
        }
    }

    // -------------------------------------------------------------------------
    // Result mapping → normalized 0-1 boxes
    // -------------------------------------------------------------------------

    private fun mapResults(
        detection: com.google.mediapipe.tasks.vision.objectdetector.ObjectDetectorResult,
        imageWidth: Int,
        imageHeight: Int,
    ): List<Map<String, Any>> {
        if (imageWidth <= 0 || imageHeight <= 0) return emptyList()
        val w = imageWidth.toDouble()
        val h = imageHeight.toDouble()
        return detection.detections().mapNotNull { det ->
            val category = det.categories().maxByOrNull { it.score() } ?: return@mapNotNull null
            val box = det.boundingBox()
            mapOf(
                "label" to category.categoryName(),
                "confidence" to category.score().toDouble(),
                "left" to (box.left / w).coerceIn(0.0, 1.0),
                "top" to (box.top / h).coerceIn(0.0, 1.0),
                "right" to (box.right / w).coerceIn(0.0, 1.0),
                "bottom" to (box.bottom / h).coerceIn(0.0, 1.0),
            )
        }
    }

    // -------------------------------------------------------------------------
    // Frame → Bitmap conversion
    // -------------------------------------------------------------------------

    private fun yuvToBitmap(
        yBytes: ByteArray,
        uBytes: ByteArray,
        vBytes: ByteArray,
        width: Int,
        height: Int,
        yRowStride: Int,
        uvRowStride: Int,
        uvPixelStride: Int,
    ): Bitmap? {
        // Repack the planes into tightly-packed NV21, then JPEG-decode to ARGB.
        val nv21 = ByteArray(width * height + width * (height / 2))
        var pos = 0
        if (yRowStride == width) {
            System.arraycopy(yBytes, 0, nv21, 0, width * height)
            pos = width * height
        } else {
            for (row in 0 until height) {
                System.arraycopy(yBytes, row * yRowStride, nv21, pos, width)
                pos += width
            }
        }
        val uvHeight = height / 2
        val uvWidth = width / 2
        for (row in 0 until uvHeight) {
            for (col in 0 until uvWidth) {
                val uvIndex = row * uvRowStride + col * uvPixelStride
                nv21[pos++] = vBytes[uvIndex]
                nv21[pos++] = uBytes[uvIndex]
            }
        }
        val yuvImage = YuvImage(nv21, ImageFormat.NV21, width, height, null)
        val jpegOut = ByteArrayOutputStream()
        val ok = yuvImage.compressToJpeg(Rect(0, 0, width, height), 85, jpegOut)
        if (!ok) {
            jpegOut.close()
            return null
        }
        val bytes = jpegOut.toByteArray()
        jpegOut.close()
        return BitmapFactory.decodeByteArray(bytes, 0, bytes.size)
    }

    private fun bgraToBitmap(
        bytes: ByteArray,
        width: Int,
        height: Int,
        bytesPerRow: Int,
    ): Bitmap? {
        val bitmap = Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888)
        val pixels = IntArray(width * height)
        val stride = bytesPerRow
        var p = 0
        for (row in 0 until height) {
            var col = 0
            var idx = row * stride
            while (col < width) {
                // Source is BGRA byte order; pack into ARGB int.
                val b = bytes[idx].toInt() and 0xFF
                val g = bytes[idx + 1].toInt() and 0xFF
                val r = bytes[idx + 2].toInt() and 0xFF
                val a = bytes[idx + 3].toInt() and 0xFF
                pixels[p++] = (a shl 24) or (r shl 16) or (g shl 8) or b
                idx += 4
                col++
            }
        }
        bitmap.setPixels(pixels, 0, width, 0, 0, width, height)
        return bitmap
    }

    private fun rotateBitmap(bitmap: Bitmap, rotation: Int): Bitmap {
        if (rotation == 0) return bitmap
        val matrix = Matrix().apply { postRotate(rotation.toFloat()) }
        val rotated = Bitmap.createBitmap(
            bitmap, 0, 0, bitmap.width, bitmap.height, matrix, true,
        )
        if (rotated != bitmap) bitmap.recycle()
        return rotated
    }

    private fun decodeBitmapWithOrientation(file: File): Bitmap? {
        val bitmap = BitmapFactory.decodeFile(file.absolutePath) ?: return null
        val exif = ExifInterface(file.absolutePath)
        val orientation = exif.getAttributeInt(
            ExifInterface.TAG_ORIENTATION,
            ExifInterface.ORIENTATION_NORMAL,
        )
        val matrix = Matrix()
        when (orientation) {
            ExifInterface.ORIENTATION_ROTATE_90 -> matrix.postRotate(90f)
            ExifInterface.ORIENTATION_ROTATE_180 -> matrix.postRotate(180f)
            ExifInterface.ORIENTATION_ROTATE_270 -> matrix.postRotate(270f)
            ExifInterface.ORIENTATION_FLIP_HORIZONTAL -> matrix.preScale(-1f, 1f)
            ExifInterface.ORIENTATION_FLIP_VERTICAL -> matrix.preScale(1f, -1f)
        }
        return if (matrix.isIdentity) bitmap
        else Bitmap.createBitmap(bitmap, 0, 0, bitmap.width, bitmap.height, matrix, true)
    }

    private fun assetExists(context: Context, name: String): Boolean {
        return try {
            context.assets.open(name).use { true }
        } catch (_: Exception) {
            false
        }
    }

    companion object {
        private const val TAG = "ObjectDetection"
        private const val CHANNEL = "com.oguzhan.imageflow/object_detection"
        private const val MODEL_ASSET = "efficientdet_lite0.tflite"
        private const val SCORE_THRESHOLD = 0.5f
        private const val MAX_RESULTS = 10
    }
}
