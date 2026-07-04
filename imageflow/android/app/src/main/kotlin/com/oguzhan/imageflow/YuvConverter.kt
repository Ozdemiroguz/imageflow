package com.oguzhan.imageflow

import android.graphics.Bitmap
import android.graphics.ImageFormat
import android.graphics.Rect
import android.graphics.YuvImage
import android.os.Build
import org.opencv.android.Utils
import org.opencv.core.CvType
import org.opencv.core.Mat
import org.opencv.imgproc.Imgproc
import java.io.ByteArrayOutputStream

/**
 * Shared camera-frame conversion for the realtime handlers.
 *
 * Both the corner (document) and object detectors receive raw YUV_420_888
 * planes and need pixels in a workable form — OpenCV [Mat] for edge detection,
 * [Bitmap] for MediaPipe. Previously each handler repacked the planes and did
 * its own conversion, and the object handler went YUV -> JPEG -> Bitmap, which
 * allocated a large JPEG buffer + Bitmap every frame and hammered the GC (one
 * GC per frame, causing memory-pressure black screens).
 *
 * This centralizes the repack once and converts via OpenCV's native color
 * conversion — no JPEG encode/decode — so neither handler duplicates the work
 * and the per-frame large-object churn is gone.
 *
 * On the emulator OpenCV's NV21 color conversion can crash (SIGILL on some
 * frames), so a JPEG fallback is kept for that path only — real devices never
 * hit it.
 */
object YuvConverter {

    /**
     * Repack YUV_420_888 planes (which may carry row/pixel stride padding) into
     * a tightly packed NV21 buffer (Y plane followed by interleaved V,U).
     */
    fun toNv21(
        yBytes: ByteArray,
        uBytes: ByteArray,
        vBytes: ByteArray,
        width: Int,
        height: Int,
        yRowStride: Int,
        uvRowStride: Int,
        uvPixelStride: Int,
    ): ByteArray {
        val nv21 = ByteArray(width * height + width * (height / 2))
        var pos = 0

        // Y plane — strip row padding if present.
        if (yRowStride == width) {
            System.arraycopy(yBytes, 0, nv21, 0, width * height)
            pos = width * height
        } else {
            for (row in 0 until height) {
                System.arraycopy(yBytes, row * yRowStride, nv21, pos, width)
                pos += width
            }
        }

        // Interleave V,U into NV21 order.
        val uvHeight = height / 2
        val uvWidth = width / 2
        for (row in 0 until uvHeight) {
            for (col in 0 until uvWidth) {
                val uvIndex = row * uvRowStride + col * uvPixelStride
                nv21[pos++] = vBytes[uvIndex]
                nv21[pos++] = uBytes[uvIndex]
            }
        }
        return nv21
    }

    /**
     * NV21 -> OpenCV BGR [Mat] via native color conversion (no JPEG).
     * Caller owns the returned Mat and must release it.
     */
    fun nv21ToBgrMat(nv21: ByteArray, width: Int, height: Int): Mat {
        val yuvMat = Mat(height + height / 2, width, CvType.CV_8UC1)
        yuvMat.put(0, 0, nv21)
        val bgrMat = Mat()
        Imgproc.cvtColor(yuvMat, bgrMat, Imgproc.COLOR_YUV2BGR_NV21)
        yuvMat.release()
        return bgrMat
    }

    /**
     * NV21 -> RGBA [Bitmap] via OpenCV native color conversion (no JPEG).
     *
     * [emulatorMode] uses a JPEG fallback because OpenCV's NV21 conversion can
     * crash on the emulator; real devices take the fast native path.
     */
    fun nv21ToBitmap(
        nv21: ByteArray,
        width: Int,
        height: Int,
        emulatorMode: Boolean,
    ): Bitmap? {
        if (emulatorMode) {
            return nv21ToBitmapViaJpeg(nv21, width, height)
        }
        val yuvMat = Mat(height + height / 2, width, CvType.CV_8UC1)
        yuvMat.put(0, 0, nv21)
        val rgbaMat = Mat()
        Imgproc.cvtColor(yuvMat, rgbaMat, Imgproc.COLOR_YUV2RGBA_NV21)
        yuvMat.release()

        val bitmap = Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888)
        Utils.matToBitmap(rgbaMat, bitmap)
        rgbaMat.release()
        return bitmap
    }

    private fun nv21ToBitmapViaJpeg(nv21: ByteArray, width: Int, height: Int): Bitmap? {
        val yuvImage = YuvImage(nv21, ImageFormat.NV21, width, height, null)
        val jpegOut = ByteArrayOutputStream()
        val ok = yuvImage.compressToJpeg(Rect(0, 0, width, height), 85, jpegOut)
        if (!ok) {
            jpegOut.close()
            return null
        }
        val bytes = jpegOut.toByteArray()
        jpegOut.close()
        return android.graphics.BitmapFactory.decodeByteArray(bytes, 0, bytes.size)
    }

    /**
     * Whether we're on an emulator, where OpenCV's NV21 color conversion can
     * crash (SIGILL). Both handlers share this so the JPEG fallback is chosen
     * consistently.
     */
    fun isEmulator(): Boolean {
        val fingerprint = Build.FINGERPRINT.lowercase()
        val model = Build.MODEL.lowercase()
        val manufacturer = Build.MANUFACTURER.lowercase()
        val brand = Build.BRAND.lowercase()
        val device = Build.DEVICE.lowercase()
        val product = Build.PRODUCT.lowercase()
        return fingerprint.contains("generic") ||
            fingerprint.contains("emulator") ||
            model.contains("emulator") ||
            model.contains("sdk") ||
            manufacturer.contains("genymotion") ||
            (brand.startsWith("generic") && device.startsWith("generic")) ||
            product.contains("sdk") ||
            product.contains("emulator")
    }
}
