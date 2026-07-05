import CoreImage
import CoreVideo
import Foundation

/// Shared frame-downscaler for the realtime Vision handlers.
///
/// The Flutter camera stream ships full-resolution (1080p) 32BGRA frame bytes
/// across the method channel. Feeding those straight to Vision meant allocating
/// and memcpy-ing a fresh ~8 MB `CVPixelBuffer` per frame, and — for the
/// rectangle detector — running Vision at full 1080p. Neither is needed:
///
/// - Vision's rectangle/object results are normalized (0..1), so the source
///   resolution doesn't change the result.
/// - The object model's request already `.scaleFill`s its input down, so the
///   full-res buffer was pure waste there.
///
/// This scales the incoming bytes into a small output buffer once, capped at a
/// caller-chosen long side, so the per-frame allocation and the Vision work both
/// shrink. It mirrors the Android `YuvConverter` downscale-during-conversion
/// fix. Output buffers come from a reused `CVPixelBufferPool` (recreated only
/// when the output dimensions change), so steady-state has no per-frame buffer
/// allocation churn.
///
/// Not thread-safe on its own: each handler owns its own instance and only ever
/// touches it from that handler's serial `frameProcessingQueue`.
final class PixelBufferDownscaler {

    // A single CIContext is expensive to build but cheap to reuse; it renders on
    // the GPU (Metal) so the scale is off the CPU. Reused across frames.
    private let context: CIContext
    private var pool: CVPixelBufferPool?
    private var poolWidth = 0
    private var poolHeight = 0

    init() {
        // No color management: we're scaling raw camera BGRA for detection, not
        // display, so skip the working-space conversions for speed.
        context = CIContext(options: [
            .workingColorSpace: NSNull(),
            .outputColorSpace: NSNull(),
        ])
    }

    /// Scale `bytes` (a single-plane 32BGRA image of `width`x`height` with the
    /// given `bytesPerRow`) into a new BGRA `CVPixelBuffer` whose long side is at
    /// most `maxLongSide`. Returns nil on failure. If the source is already no
    /// larger than `maxLongSide`, it is copied at full size (still pooled).
    func downscale(
        bytes: Data,
        width: Int,
        height: Int,
        bytesPerRow: Int,
        maxLongSide: Int
    ) -> CVPixelBuffer? {
        let longSide = max(width, height)
        let scale = (maxLongSide > 0 && longSide > maxLongSide)
            ? Double(maxLongSide) / Double(longSide)
            : 1.0
        // Keep dimensions even (some Vision/Metal paths prefer it) and non-zero.
        let outW = max(2, (Int(Double(width) * scale) / 2) * 2)
        let outH = max(2, (Int(Double(height) * scale) / 2) * 2)

        guard let output = makeBuffer(width: outW, height: outH) else { return nil }

        // Wrap the source bytes as a CIImage. CIImage(bitmapData:) copies the
        // bytes internally, so `bytes` doesn't need to outlive this call.
        let sourceImage = CIImage(
            bitmapData: bytes,
            bytesPerRow: bytesPerRow,
            size: CGSize(width: width, height: height),
            format: .BGRA8,
            colorSpace: nil
        )

        let scaled = scale == 1.0
            ? sourceImage
            : sourceImage.transformed(
                by: CGAffineTransform(scaleX: CGFloat(scale), y: CGFloat(scale))
            )

        context.render(scaled, to: output)
        return output
    }

    /// A pooled BGRA buffer of the given size, recreating the pool only when the
    /// dimensions change (i.e. once, since the frame size is stable).
    private func makeBuffer(width: Int, height: Int) -> CVPixelBuffer? {
        if pool == nil || width != poolWidth || height != poolHeight {
            let bufferAttrs: [String: Any] = [
                kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
                kCVPixelBufferWidthKey as String: width,
                kCVPixelBufferHeightKey as String: height,
                kCVPixelBufferIOSurfacePropertiesKey as String: [:] as [String: Any],
            ]
            var newPool: CVPixelBufferPool?
            let status = CVPixelBufferPoolCreate(
                kCFAllocatorDefault,
                nil,
                bufferAttrs as CFDictionary,
                &newPool
            )
            guard status == kCVReturnSuccess, let created = newPool else { return nil }
            pool = created
            poolWidth = width
            poolHeight = height
        }

        guard let pool = pool else { return nil }
        var buffer: CVPixelBuffer?
        let status = CVPixelBufferPoolCreatePixelBuffer(kCFAllocatorDefault, pool, &buffer)
        guard status == kCVReturnSuccess else { return nil }
        return buffer
    }
}
