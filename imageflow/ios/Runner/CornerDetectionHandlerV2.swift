import Flutter
import UIKit
import Vision
import ImageIO

/// V2: Uses CGImage + CGImagePropertyOrientation for correct coordinate mapping.
///
/// Key difference from V1: CIImage.extent ignores EXIF orientation, causing
/// coordinate mismatch. CGImageSource lets us read both the raw CGImage and
/// its EXIF orientation, then pass orientation explicitly to VNImageRequestHandler.
/// Vision then returns coordinates in the EXIF-corrected frame.
class CornerDetectionHandlerV2: NSObject, FlutterPlugin {

    private var frameBusy = false
    private let frameStateQueue = DispatchQueue(label: "com.oguzhan.imageflow.corner.state")
    private let frameProcessingQueue = DispatchQueue(
        label: "com.oguzhan.imageflow.corner.processing",
        qos: .userInitiated
    )

    static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(
            name: "com.oguzhan.imageflow/corner_detection",
            binaryMessenger: registrar.messenger()
        )
        let instance = CornerDetectionHandlerV2()
        registrar.addMethodCallDelegate(instance, channel: channel)
    }

    func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "detectCorners":
            guard let args = call.arguments as? [String: Any],
                  let imagePath = args["imagePath"] as? String else {
                result(FlutterError(code: "INVALID_ARGS", message: "imagePath required", details: nil))
                return
            }
            detectCorners(imagePath: imagePath, result: result)
        case "detectCornersFromFrame":
            guard let args = call.arguments as? [String: Any],
                  let bytes = args["bytes"] as? FlutterStandardTypedData,
                  let width = args["width"] as? Int,
                  let height = args["height"] as? Int,
                  let bytesPerRow = args["bytesPerRow"] as? Int,
                  let rotation = args["rotation"] as? Int else {
                result(FlutterError(code: "INVALID_ARGS", message: "bytes/width/height/bytesPerRow/rotation required", details: nil))
                return
            }
            detectCornersFromFrame(
                bytes: bytes.data,
                width: width,
                height: height,
                bytesPerRow: bytesPerRow,
                rotation: rotation,
                result: result
            )
        default:
            result(FlutterMethodNotImplemented)
        }
    }

    private func detectCorners(imagePath: String, result: @escaping FlutterResult) {
        let url = URL(fileURLWithPath: imagePath) as CFURL

        guard let source = CGImageSourceCreateWithURL(url, nil),
              let cgImage = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
            result(FlutterError(code: "INVALID_IMAGE", message: "Cannot load image", details: nil))
            return
        }

        let orientation = readOrientation(source: source)
        let (displayWidth, displayHeight) = displaySize(
            rawWidth: cgImage.width,
            rawHeight: cgImage.height,
            orientation: orientation
        )

        let request = VNDetectRectanglesRequest { [weak self] request, error in
            guard self != nil else { return }

            if let error = error {
                result(FlutterError(code: "DETECTION_ERROR", message: error.localizedDescription, details: nil))
                return
            }

            guard let observation = (request.results as? [VNRectangleObservation])?.first else {
                result(nil)
                return
            }

            // Vision normalized coords (0-1), bottom-left origin in the oriented frame.
            // Convert to pixel coords with top-left origin, clamped to display bounds.
            let w = Double(displayWidth)
            let h = Double(displayHeight)

            func toPixel(_ pt: CGPoint) -> (Double, Double) {
                let px = min(max(Double(pt.x) * w, 0), w)
                let py = min(max((1 - Double(pt.y)) * h, 0), h)
                return (px, py)
            }

            let (tlX, tlY) = toPixel(observation.topLeft)
            let (trX, trY) = toPixel(observation.topRight)
            let (brX, brY) = toPixel(observation.bottomRight)
            let (blX, blY) = toPixel(observation.bottomLeft)

            let corners: [String: Double] = [
                "topLeftX": tlX, "topLeftY": tlY,
                "topRightX": trX, "topRightY": trY,
                "bottomRightX": brX, "bottomRightY": brY,
                "bottomLeftX": blX, "bottomLeftY": blY,
            ]

            result(corners)
        }

        request.minimumConfidence = 0.3
        request.maximumObservations = 1
        request.minimumAspectRatio = 0.1
        request.maximumAspectRatio = 1.0
        request.minimumSize = 0.05

        let handler = VNImageRequestHandler(cgImage: cgImage, orientation: orientation, options: [:])

        DispatchQueue.global(qos: .userInitiated).async {
            do {
                try handler.perform([request])
            } catch {
                result(FlutterError(code: "HANDLER_ERROR", message: error.localizedDescription, details: nil))
            }
        }
    }

    // MARK: - Frame-based detection (realtime camera stream)

    private func detectCornersFromFrame(
        bytes: Data,
        width: Int,
        height: Int,
        bytesPerRow: Int,
        rotation: Int,
        result: @escaping FlutterResult
    ) {
        // Backpressure: drop frame if previous one is still processing
        guard acquireFrameSlot() else {
            result(nil)
            return
        }

        // Validate bytes length
        let expectedLength = bytesPerRow * height
        guard bytes.count >= expectedLength else {
            releaseFrameSlot()
            result(nil)
            return
        }

        frameProcessingQueue.async { [weak self] in
            autoreleasepool {
                defer { self?.releaseFrameSlot() }

                // Create CVPixelBuffer from raw bytes
                var pixelBuffer: CVPixelBuffer?
                let attrs: [String: Any] = [
                    kCVPixelBufferIOSurfacePropertiesKey as String: [:] as [String: Any],
                ]
                let status = CVPixelBufferCreate(
                    kCFAllocatorDefault,
                    width,
                    height,
                    kCVPixelFormatType_32BGRA,
                    attrs as CFDictionary,
                    &pixelBuffer
                )

                guard status == kCVReturnSuccess, let buffer = pixelBuffer else {
                    DispatchQueue.main.async {
                        result(FlutterError(code: "BUFFER_ERROR", message: "Failed to create pixel buffer", details: nil))
                    }
                    return
                }

                CVPixelBufferLockBaseAddress(buffer, [])
                let dest = CVPixelBufferGetBaseAddress(buffer)
                let destBytesPerRow = CVPixelBufferGetBytesPerRow(buffer)

                bytes.withUnsafeBytes { srcPtr in
                    guard let srcBase = srcPtr.baseAddress else { return }
                    // Copy row by row in case bytesPerRow differs
                    for row in 0..<height {
                        let srcRow = srcBase.advanced(by: row * bytesPerRow)
                        let destRow = dest!.advanced(by: row * destBytesPerRow)
                        memcpy(destRow, srcRow, min(bytesPerRow, destBytesPerRow))
                    }
                }
                CVPixelBufferUnlockBaseAddress(buffer, [])

                // Map rotation degrees to CGImagePropertyOrientation
                let orientation: CGImagePropertyOrientation
                switch rotation {
                case 90:  orientation = .right
                case 180: orientation = .down
                case 270: orientation = .left
                default:  orientation = .up
                }

                let request = VNDetectRectanglesRequest { req, error in
                    if error != nil {
                        DispatchQueue.main.async { result(nil) }
                        return
                    }

                    guard let observation = (req.results as? [VNRectangleObservation])?.first else {
                        DispatchQueue.main.async { result(nil) }
                        return
                    }

                    func toNorm(_ pt: CGPoint) -> (Double, Double) {
                        let nx = min(max(Double(pt.x), 0), 1)
                        let ny = min(max(1 - Double(pt.y), 0), 1)
                        return (nx, ny)
                    }

                    let (tlX, tlY) = toNorm(observation.topLeft)
                    let (trX, trY) = toNorm(observation.topRight)
                    let (brX, brY) = toNorm(observation.bottomRight)
                    let (blX, blY) = toNorm(observation.bottomLeft)

                    let corners: [String: Double] = [
                        "topLeftX": tlX, "topLeftY": tlY,
                        "topRightX": trX, "topRightY": trY,
                        "bottomRightX": brX, "bottomRightY": brY,
                        "bottomLeftX": blX, "bottomLeftY": blY,
                    ]

                    DispatchQueue.main.async { result(corners) }
                }

                request.minimumConfidence = 0.3
                request.maximumObservations = 1
                request.minimumAspectRatio = 0.1
                request.maximumAspectRatio = 1.0
                request.minimumSize = 0.05

                let handler = VNImageRequestHandler(cvPixelBuffer: buffer, orientation: orientation, options: [:])
                do {
                    try handler.perform([request])
                } catch {
                    DispatchQueue.main.async { result(nil) }
                }
            }
        }
    }

    // MARK: - Helpers

    /// Read CGImagePropertyOrientation from image source EXIF data.
    private func readOrientation(source: CGImageSource) -> CGImagePropertyOrientation {
        guard let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let raw = properties[kCGImagePropertyOrientation] as? UInt32,
              let orientation = CGImagePropertyOrientation(rawValue: raw) else {
            return .up
        }
        return orientation
    }

    private func acquireFrameSlot() -> Bool {
        frameStateQueue.sync {
            if frameBusy { return false }
            frameBusy = true
            return true
        }
    }

    private func releaseFrameSlot() {
        frameStateQueue.async { [weak self] in
            self?.frameBusy = false
        }
    }

    /// Calculate display dimensions after EXIF orientation is applied.
    private func displaySize(
        rawWidth: Int,
        rawHeight: Int,
        orientation: CGImagePropertyOrientation
    ) -> (Int, Int) {
        switch orientation {
        case .left, .leftMirrored, .right, .rightMirrored:
            // 90° or 270° rotation swaps width/height
            return (rawHeight, rawWidth)
        default:
            return (rawWidth, rawHeight)
        }
    }
}
