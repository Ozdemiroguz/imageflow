package com.oguzhan.imageflow

import android.graphics.BitmapFactory
import android.graphics.Matrix
import android.os.Handler
import android.os.Looper
import android.util.Log
import androidx.exifinterface.media.ExifInterface
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import org.opencv.android.OpenCVLoader
import org.opencv.android.Utils
import org.opencv.core.Core
import org.opencv.core.CvType
import org.opencv.core.Mat
import org.opencv.core.MatOfPoint
import org.opencv.core.MatOfPoint2f
import org.opencv.core.Point
import org.opencv.core.Size
import org.opencv.imgproc.Imgproc
import java.io.File
import java.util.concurrent.Executors

/// Handles Method Channel calls for document corner detection on Android.
///
/// Uses OpenCV 4.13.0 (official AAR via org.opencv:opencv) for edge detection.
/// Algorithm: grayscale → GaussianBlur → threshold(TRIANGLE) → Canny(75,200)
/// → dilate(9x9) → findContours → approxPolyDP → 4-corner convex quad.
///
/// Returns pixel coordinates in the same format as the iOS Vision handler:
/// Map<String, Double> with keys: topLeftX/Y, topRightX/Y, bottomRightX/Y, bottomLeftX/Y.
class CornerDetectionHandler : FlutterPlugin, MethodCallHandler {

    private lateinit var channel: MethodChannel
    private val executor = Executors.newSingleThreadExecutor()
    private val mainHandler = Handler(Looper.getMainLooper())
    private var opencvReady = false
    @Volatile private var frameBusy = false
    private val emulatorMode by lazy { YuvConverter.isEmulator() }

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel = MethodChannel(binding.binaryMessenger, "com.oguzhan.imageflow/corner_detection")
        channel.setMethodCallHandler(this)
        opencvReady = OpenCVLoader.initLocal()
        if (opencvReady && emulatorMode) {
            // Emulator can crash in OpenCV parallel color conversion (SIGILL on some images).
            Core.setUseOptimized(false)
            Core.setNumThreads(1)
        }
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
    }

    override fun onMethodCall(call: MethodCall, result: Result) {
        when (call.method) {
            "detectCorners" -> {
                val imagePath = call.argument<String>("imagePath")
                if (imagePath == null) {
                    result.error("INVALID_ARGS", "imagePath required", null)
                    return
                }
                if (!opencvReady) {
                    result.success(null)
                    return
                }
                executor.execute {
                    try {
                        val corners = detectCorners(imagePath)
                        mainHandler.post { result.success(corners) }
                    } catch (e: Exception) {
                        mainHandler.post {
                            result.error("DETECTION_ERROR", e.message, null)
                        }
                    }
                }
            }
            "detectCornersFromFrame" -> {
                val width = call.argument<Int>("width")
                val height = call.argument<Int>("height")
                val rotation = call.argument<Int>("rotation") ?: 0
                val format = call.argument<String>("format") ?: "bgra"
                if (width == null || height == null) {
                    result.error("INVALID_ARGS", "width/height required", null)
                    return
                }
                if (!opencvReady || frameBusy) {
                    result.success(null)
                    return
                }
                frameBusy = true
                executor.execute {
                    try {
                        val corners = when (format) {
                            "yuv420" -> {
                                val yBytes = call.argument<ByteArray>("yBytes")
                                val uBytes = call.argument<ByteArray>("uBytes")
                                val vBytes = call.argument<ByteArray>("vBytes")
                                val yRowStride = call.argument<Int>("yRowStride") ?: width
                                val uvRowStride = call.argument<Int>("uvRowStride") ?: width
                                val uvPixelStride = call.argument<Int>("uvPixelStride") ?: 1
                                if (yBytes == null || uBytes == null || vBytes == null) {
                                    mainHandler.post { result.error("INVALID_ARGS", "yBytes/uBytes/vBytes required for yuv420", null) }
                                    frameBusy = false
                                    return@execute
                                }
                                detectCornersFromYuv(yBytes, uBytes, vBytes, width, height, yRowStride, uvRowStride, uvPixelStride, rotation)
                            }
                            else -> {
                                val bytes = call.argument<ByteArray>("bytes")
                                val bytesPerRow = call.argument<Int>("bytesPerRow") ?: (width * 4)
                                if (bytes == null) {
                                    mainHandler.post { result.error("INVALID_ARGS", "bytes required for bgra", null) }
                                    frameBusy = false
                                    return@execute
                                }
                                detectCornersFromBgra(bytes, width, height, bytesPerRow, rotation)
                            }
                        }
                        mainHandler.post { result.success(corners) }
                    } catch (e: Exception) {
                        // Per-frame hot path: a failure means "drop this frame"
                        // (null = no rectangle), matching the Dart contract — but
                        // log it so a real crash (OOM, OpenCV) isn't invisible.
                        Log.w("CornerDetection", "Frame detection failed", e)
                        mainHandler.post { result.success(null) }
                    } finally {
                        frameBusy = false
                    }
                }
            }
            else -> result.notImplemented()
        }
    }

    private fun detectCorners(imagePath: String): Map<String, Double>? {
        val file = File(imagePath)
        if (!file.exists()) return null

        // Load bitmap with EXIF orientation baked in
        val bitmap = decodeBitmapWithOrientation(file) ?: return null
        val origW = bitmap.width
        val origH = bitmap.height

        // Downsample for faster edge detection (max 1000px on longest side)
        val maxDim = 1000
        val scale: Double
        val workBitmap: android.graphics.Bitmap
        if (origW > maxDim || origH > maxDim) {
            scale = maxDim.toDouble() / maxOf(origW, origH)
            val newW = (origW * scale).toInt()
            val newH = (origH * scale).toInt()
            workBitmap = android.graphics.Bitmap.createScaledBitmap(bitmap, newW, newH, true)
            // The scaled copy replaces the original; release the full-size
            // bitmap now instead of waiting for GC (matters on repeated calls).
            bitmap.recycle()
        } else {
            scale = 1.0
            workBitmap = bitmap
        }

        // Convert to OpenCV Mat, then release the bitmap's native pixels.
        val src = Mat()
        Utils.bitmapToMat(workBitmap, src)
        workBitmap.recycle()

        // Find contours using proven edge detection pipeline
        val contours = findContours(src)
        src.release()

        if (contours.isEmpty()) return null

        // Find best 4-corner polygon from contours
        val quad = findBestQuad(contours) ?: return null

        // Order corners: TL, TR, BR, BL — scale back to original pixel coordinates
        val ordered = orderCorners(quad)
        val invScale = 1.0 / scale

        return mapOf(
            "topLeftX" to (ordered[0].x * invScale).coerceIn(0.0, origW.toDouble()),
            "topLeftY" to (ordered[0].y * invScale).coerceIn(0.0, origH.toDouble()),
            "topRightX" to (ordered[1].x * invScale).coerceIn(0.0, origW.toDouble()),
            "topRightY" to (ordered[1].y * invScale).coerceIn(0.0, origH.toDouble()),
            "bottomRightX" to (ordered[2].x * invScale).coerceIn(0.0, origW.toDouble()),
            "bottomRightY" to (ordered[2].y * invScale).coerceIn(0.0, origH.toDouble()),
            "bottomLeftX" to (ordered[3].x * invScale).coerceIn(0.0, origW.toDouble()),
            "bottomLeftY" to (ordered[3].y * invScale).coerceIn(0.0, origH.toDouble()),
        )
    }

    // -------------------------------------------------------------------------
    // Frame-based detection (realtime camera stream)
    // -------------------------------------------------------------------------

    /// Reconstruct NV21 from individual YUV planes respecting row strides,
    /// then run edge detection. Handles all YUV_420_888 layouts (NV21, NV12, I420).
    private fun detectCornersFromYuv(
        yBytes: ByteArray,
        uBytes: ByteArray,
        vBytes: ByteArray,
        width: Int,
        height: Int,
        yRowStride: Int,
        uvRowStride: Int,
        uvPixelStride: Int,
        rotation: Int,
    ): Map<String, Double>? {
        // Shared conversion: repack strided planes into tightly-packed NV21.
        val nv21 = YuvConverter.toNv21(
            yBytes, uBytes, vBytes, width, height,
            yRowStride, uvRowStride, uvPixelStride,
        )

        if (emulatorMode) {
            // Safer path for emulator: avoid OpenCV NV21 -> BGR conversion crash.
            val bitmap = YuvConverter.nv21ToBitmap(nv21, width, height, emulatorMode = true)
                ?: return null
            val mat = Mat()
            Utils.bitmapToMat(bitmap, mat)
            bitmap.recycle()
            return detectAndNormalize(mat, rotation)
        }

        // Downscale AS A MAT during the YUV->BGR conversion so a full-res
        // (e.g. 1080p ~6MB) BGR Mat is never allocated per frame — the edge
        // pipeline runs at ~720px and corners are normalized. detectAndNormalize
        // still caps at 720 as a safety net for the BGRA/emulator paths, but for
        // the common YUV path the Mat already arrives small, so that second pass
        // is a no-op (identity). This is the corner-detector twin of the object
        // handler's pre-scaled bitmap and the main Large-Object-Space win.
        val bgrMat = YuvConverter.nv21ToBgrMat(nv21, width, height, maxLongSide = 720)
        return detectAndNormalize(bgrMat, rotation)
    }

    /// BGRA frame (iOS default). Handles bytesPerRow padding correctly.
    private fun detectCornersFromBgra(
        bytes: ByteArray,
        width: Int,
        height: Int,
        bytesPerRow: Int,
        rotation: Int,
    ): Map<String, Double>? {
        val mat: Mat
        if (bytesPerRow == width * 4) {
            // No padding — direct load
            mat = Mat(height, width, CvType.CV_8UC4)
            mat.put(0, 0, bytes)
        } else {
            // Row padding exists — load with stride then crop
            val stridePixels = bytesPerRow / 4
            val padded = Mat(height, stridePixels, CvType.CV_8UC4)
            padded.put(0, 0, bytes)
            mat = padded.submat(0, height, 0, width).clone()
            padded.release()
        }

        return detectAndNormalize(mat, rotation)
    }

    /// Apply rotation, run edge detection, return normalized 0-1 coordinates.
    private fun detectAndNormalize(mat: Mat, rotation: Int): Map<String, Double>? {
        val rotated = when (rotation) {
            90 -> {
                val dst = Mat()
                org.opencv.core.Core.rotate(mat, dst, org.opencv.core.Core.ROTATE_90_CLOCKWISE)
                mat.release()
                dst
            }
            180 -> {
                val dst = Mat()
                org.opencv.core.Core.rotate(mat, dst, org.opencv.core.Core.ROTATE_180)
                mat.release()
                dst
            }
            270 -> {
                val dst = Mat()
                org.opencv.core.Core.rotate(mat, dst, org.opencv.core.Core.ROTATE_90_COUNTERCLOCKWISE)
                mat.release()
                dst
            }
            else -> mat
        }

        // Downscale before the (expensive) Canny/contour pipeline: at 1080p the
        // OpenCV pass is far heavier than it needs to be for edge detection, and
        // it allocates large Mats every frame. Cap the long side at ~720px; the
        // corners come out normalized (0..1) so the resolution doesn't matter to
        // the result — only the preview needs to stay full-res.
        val work = downscaleMat(rotated, 720)
        if (work != rotated) rotated.release()

        val frameW = work.cols().toDouble()
        val frameH = work.rows().toDouble()

        val contours = findContours(work)
        work.release()

        if (contours.isEmpty()) return null

        val quad = findBestQuad(contours) ?: return null
        val ordered = orderCorners(quad)

        return mapOf(
            "topLeftX" to (ordered[0].x / frameW).coerceIn(0.0, 1.0),
            "topLeftY" to (ordered[0].y / frameH).coerceIn(0.0, 1.0),
            "topRightX" to (ordered[1].x / frameW).coerceIn(0.0, 1.0),
            "topRightY" to (ordered[1].y / frameH).coerceIn(0.0, 1.0),
            "bottomRightX" to (ordered[2].x / frameW).coerceIn(0.0, 1.0),
            "bottomRightY" to (ordered[2].y / frameH).coerceIn(0.0, 1.0),
            "bottomLeftX" to (ordered[3].x / frameW).coerceIn(0.0, 1.0),
            "bottomLeftY" to (ordered[3].y / frameH).coerceIn(0.0, 1.0),
        )
    }

    // -------------------------------------------------------------------------
    // Edge detection pipeline (from flutter_edge_detection)
    // grayscale → GaussianBlur → threshold(TRIANGLE) → Canny → dilate → findContours
    // -------------------------------------------------------------------------

    /** Downscale a BGR/BGRA Mat so its long side is at most [maxLongSide].
     *  Returns the SAME Mat when already small enough (caller checks identity
     *  before releasing). Corners are normalized, so scale doesn't shift them. */
    private fun downscaleMat(src: Mat, maxLongSide: Int): Mat {
        val longSide = maxOf(src.cols(), src.rows())
        if (longSide <= maxLongSide) return src
        val scale = maxLongSide.toDouble() / longSide
        val dst = Mat()
        Imgproc.resize(
            src, dst,
            Size(src.cols() * scale, src.rows() * scale),
            0.0, 0.0, Imgproc.INTER_AREA,
        )
        return dst
    }

    private fun findContours(src: Mat): List<MatOfPoint> {
        val size = Size(src.size().width, src.size().height)
        val grayImage = Mat(size, CvType.CV_8UC4)
        val cannedImage = Mat(size, CvType.CV_8UC1)
        val kernel = Imgproc.getStructuringElement(Imgproc.MORPH_RECT, Size(9.0, 9.0))
        val dilated = Mat(size, CvType.CV_8UC1)

        Imgproc.cvtColor(src, grayImage, Imgproc.COLOR_BGR2GRAY)
        Imgproc.GaussianBlur(grayImage, grayImage, Size(5.0, 5.0), 0.0)
        Imgproc.threshold(grayImage, grayImage, 20.0, 255.0, Imgproc.THRESH_TRIANGLE)
        Imgproc.Canny(grayImage, cannedImage, 75.0, 200.0)
        Imgproc.dilate(cannedImage, dilated, kernel)

        val contours = ArrayList<MatOfPoint>()
        val hierarchy = Mat()
        Imgproc.findContours(
            dilated, contours, hierarchy,
            Imgproc.RETR_TREE, Imgproc.CHAIN_APPROX_SIMPLE,
        )

        // Filter: area > 10000, sort by area descending, take top 25
        val filtered = contours
            .filter { Imgproc.contourArea(it) > 100e2 }
            .sortedByDescending { Imgproc.contourArea(it) }
            .take(25)

        hierarchy.release()
        grayImage.release()
        cannedImage.release()
        kernel.release()
        dilated.release()

        return filtered
    }

    // -------------------------------------------------------------------------
    // Find best 4-corner convex polygon from contours
    // -------------------------------------------------------------------------

    private fun findBestQuad(contours: List<MatOfPoint>): List<Point>? {
        val limit = minOf(contours.size, 5)
        for (i in 0 until limit) {
            val c2f = MatOfPoint2f(*contours[i].toArray())
            val peri = Imgproc.arcLength(c2f, true)
            val approx = MatOfPoint2f()
            Imgproc.approxPolyDP(c2f, approx, 0.03 * peri, true)
            val points = approx.toArray().toList()

            val convex = MatOfPoint()
            approx.convertTo(convex, CvType.CV_32S)

            if (points.size == 4 && Imgproc.isContourConvex(convex)) {
                return points
            }
        }
        return null
    }

    // -------------------------------------------------------------------------
    // Order 4 corners: TL, TR, BR, BL
    // Sum(x+y): min→TL, max→BR. Diff(x-y): min→BL, max→TR (then swap to TL,TR,BR,BL)
    // -------------------------------------------------------------------------

    private fun orderCorners(points: List<Point>): List<Point> {
        val tl = points.minByOrNull { it.x + it.y } ?: Point()
        val br = points.maxByOrNull { it.x + it.y } ?: Point()
        val tr = points.minByOrNull { it.y - it.x } ?: Point()
        val bl = points.maxByOrNull { it.y - it.x } ?: Point()
        return listOf(tl, tr, br, bl)
    }

    // -------------------------------------------------------------------------
    // Bitmap loading with EXIF orientation
    // -------------------------------------------------------------------------

    private fun decodeBitmapWithOrientation(file: File): android.graphics.Bitmap? {
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
        else android.graphics.Bitmap.createBitmap(bitmap, 0, 0, bitmap.width, bitmap.height, matrix, true)
    }
}
