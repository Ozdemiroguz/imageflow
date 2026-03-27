import Flutter
import UIKit
import Vision

/// Handles Method Channel calls for document corner detection.
///
/// Uses Vision Framework's VNDetectRectanglesRequest to find document edges.
/// Returns pixel coordinates (not normalized) for the 4 corners.
class CornerDetectionHandler: NSObject, FlutterPlugin {

    static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(
            name: "com.oguzhan.imageflow/corner_detection",
            binaryMessenger: registrar.messenger()
        )
        let instance = CornerDetectionHandler()
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
        default:
            result(FlutterMethodNotImplemented)
        }
    }

    private func detectCorners(imagePath: String, result: @escaping FlutterResult) {
        let url = URL(fileURLWithPath: imagePath)

        guard let ciImage = CIImage(contentsOf: url) else {
            result(FlutterError(code: "INVALID_IMAGE", message: "Cannot load image", details: nil))
            return
        }

        let imageWidth = ciImage.extent.width
        let imageHeight = ciImage.extent.height

        let request = VNDetectRectanglesRequest { request, error in
            if let error = error {
                result(FlutterError(code: "DETECTION_ERROR", message: error.localizedDescription, details: nil))
                return
            }

            guard let observation = (request.results as? [VNRectangleObservation])?.first else {
                // No rectangle found
                result(nil)
                return
            }

            // Vision returns normalized coordinates (0-1) with origin at BOTTOM-LEFT.
            // Convert to pixel coordinates with origin at TOP-LEFT, clamped to image bounds.
            let tl = observation.topLeft
            let tr = observation.topRight
            let br = observation.bottomRight
            let bl = observation.bottomLeft

            func toPixel(_ pt: CGPoint) -> (Double, Double) {
                let px = min(max(Double(pt.x) * imageWidth, 0), imageWidth)
                let py = min(max((1 - Double(pt.y)) * imageHeight, 0), imageHeight)
                return (px, py)
            }

            let (tlX, tlY) = toPixel(tl)
            let (trX, trY) = toPixel(tr)
            let (brX, brY) = toPixel(br)
            let (blX, blY) = toPixel(bl)

            let corners: [String: Double] = [
                "topLeftX": tlX, "topLeftY": tlY,
                "topRightX": trX, "topRightY": trY,
                "bottomRightX": brX, "bottomRightY": brY,
                "bottomLeftX": blX, "bottomLeftY": blY,
            ]

            result(corners)
        }

        // Configure rectangle detection
        request.minimumConfidence = 0.5
        request.maximumObservations = 1
        request.minimumAspectRatio = 0.2
        request.maximumAspectRatio = 1.0
        request.minimumSize = 0.1

        let handler = VNImageRequestHandler(ciImage: ciImage, options: [:])

        DispatchQueue.global(qos: .userInitiated).async {
            do {
                try handler.perform([request])
            } catch {
                result(FlutterError(code: "HANDLER_ERROR", message: error.localizedDescription, details: nil))
            }
        }
    }
}
