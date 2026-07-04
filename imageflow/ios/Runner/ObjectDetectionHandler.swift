import CoreML
import Flutter
import ImageIO
import UIKit
import Vision

/// Method-channel handler for realtime + still-image object detection on iOS.
///
/// Backed by a Core ML detector run through `VNCoreMLRequest` on the ANE
/// (`.all` compute units). The model — an Apple-gallery object detector that
/// emits `VNRecognizedObjectObservation` (e.g. YOLOv3-Tiny or
/// MobileNetV2-SSDLite, both non-viral licenses) — is compiled into the bundle
/// as `[MODEL_NAME].mlmodelc`.
///
/// Graceful degradation: if the model is not bundled, `request` stays nil and
/// every call returns "no objects" so the app keeps working. Contract mirrors
/// the Dart side and the corner handler:
///   - file path  → array (possibly empty), error only on a real failure
///   - frame path → array, or nil when busy / degraded (drop-frame)
class ObjectDetectionHandler: NSObject, FlutterPlugin {

    private var frameBusy = false
    private let frameStateQueue = DispatchQueue(label: "com.oguzhan.imageflow.object.state")
    private let frameProcessingQueue = DispatchQueue(
        label: "com.oguzhan.imageflow.object.processing",
        qos: .userInitiated
    )

    // Reused across calls: building the VNCoreMLModel/request is expensive, so
    // we do it once (lazily) and keep it. VNCoreMLRequest is not thread-safe, so
    // all `perform` calls are serialized on frameProcessingQueue.
    private lazy var request: VNCoreMLRequest? = Self.makeRequest()

    static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(
            name: "com.oguzhan.imageflow/object_detection",
            binaryMessenger: registrar.messenger()
        )
        let instance = ObjectDetectionHandler()
        registrar.addMethodCallDelegate(instance, channel: channel)
    }

    func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "detectObjects":
            guard let args = call.arguments as? [String: Any],
                  let imagePath = args["imagePath"] as? String else {
                result(FlutterError(code: "INVALID_ARGS", message: "imagePath required", details: nil))
                return
            }
            detectObjects(imagePath: imagePath, result: result)
        case "detectObjectsFromFrame":
            guard let args = call.arguments as? [String: Any],
                  let bytes = args["bytes"] as? FlutterStandardTypedData,
                  let width = args["width"] as? Int,
                  let height = args["height"] as? Int,
                  let bytesPerRow = args["bytesPerRow"] as? Int,
                  let rotation = args["rotation"] as? Int else {
                // yuv420 frames are Android-only; iOS streams BGRA. If the bgra
                // args are missing, treat it as a dropped frame rather than error.
                result([[String: Any]]())
                return
            }
            detectObjectsFromFrame(
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

    // MARK: - Still image (file path)

    private func detectObjects(imagePath: String, result: @escaping FlutterResult) {
        guard let request = request else {
            // Degraded (no model): a valid "no objects" outcome, not an error.
            result([[String: Any]]())
            return
        }

        let url = URL(fileURLWithPath: imagePath) as CFURL
        guard let source = CGImageSourceCreateWithURL(url, nil),
              let cgImage = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
            result(FlutterError(code: "INVALID_IMAGE", message: "Cannot load image", details: nil))
            return
        }
        let orientation = Self.readOrientation(source: source)
        let handler = VNImageRequestHandler(cgImage: cgImage, orientation: orientation, options: [:])

        frameProcessingQueue.async {
            autoreleasepool {
                do {
                    try handler.perform([request])
                    let objects = Self.mapObjects(request.results)
                    DispatchQueue.main.async { result(objects) }
                } catch {
                    DispatchQueue.main.async {
                        result(FlutterError(code: "DETECTION_ERROR", message: error.localizedDescription, details: nil))
                    }
                }
            }
        }
    }

    // MARK: - Realtime frame (drop-frame hot path)

    private func detectObjectsFromFrame(
        bytes: Data,
        width: Int,
        height: Int,
        bytesPerRow: Int,
        rotation: Int,
        result: @escaping FlutterResult
    ) {
        guard let request = request else {
            result([[String: Any]]())
            return
        }
        guard acquireFrameSlot() else {
            result([[String: Any]]())
            return
        }
        let expectedLength = bytesPerRow * height
        guard bytes.count >= expectedLength else {
            releaseFrameSlot()
            result([[String: Any]]())
            return
        }

        frameProcessingQueue.async { [weak self] in
            autoreleasepool {
                defer { self?.releaseFrameSlot() }

                guard let buffer = Self.makePixelBuffer(
                    bytes: bytes, width: width, height: height, bytesPerRow: bytesPerRow
                ) else {
                    DispatchQueue.main.async { result([[String: Any]]()) }
                    return
                }

                let orientation: CGImagePropertyOrientation
                switch rotation {
                case 90:  orientation = .right
                case 180: orientation = .down
                case 270: orientation = .left
                default:  orientation = .up
                }

                let handler = VNImageRequestHandler(cvPixelBuffer: buffer, orientation: orientation, options: [:])
                do {
                    try handler.perform([request])
                    let objects = Self.mapObjects(request.results)
                    DispatchQueue.main.async { result(objects) }
                } catch {
                    DispatchQueue.main.async { result([[String: Any]]()) }
                }
            }
        }
    }

    // MARK: - Model / request

    private static func makeRequest() -> VNCoreMLRequest? {
        guard let model = loadModel() else {
            NSLog("[ObjectDetection] Core ML model '\(modelName)' not bundled; degrading to no-op.")
            return nil
        }
        let request = VNCoreMLRequest(model: model)
        // Let Vision letterbox/scale the input to the model's expected size.
        request.imageCropAndScaleOption = .scaleFill
        return request
    }

    private static func loadModel() -> VNCoreMLModel? {
        let config = MLModelConfiguration()
        config.computeUnits = .all // prefer the Neural Engine
        // Prefer a precompiled .mlmodelc; fall back to compiling a raw .mlmodel.
        if let url = Bundle.main.url(forResource: modelName, withExtension: "mlmodelc"),
           let mlModel = try? MLModel(contentsOf: url, configuration: config),
           let visionModel = try? VNCoreMLModel(for: mlModel) {
            return visionModel
        }
        if let rawUrl = Bundle.main.url(forResource: modelName, withExtension: "mlmodel"),
           let compiledUrl = try? MLModel.compileModel(at: rawUrl),
           let mlModel = try? MLModel(contentsOf: compiledUrl, configuration: config),
           let visionModel = try? VNCoreMLModel(for: mlModel) {
            return visionModel
        }
        return nil
    }

    // MARK: - Result mapping → normalized 0-1 boxes

    private static func mapObjects(_ results: [VNObservation]?) -> [[String: Any]] {
        guard let observations = results as? [VNRecognizedObjectObservation] else {
            return [[String: Any]]()
        }
        return observations.compactMap { obs -> [String: Any]? in
            guard let top = obs.labels.first else { return nil }
            // Vision boxes: normalized (0-1), bottom-left origin. Flip Y so the
            // box matches the top-left origin the Dart overlay expects.
            let bb = obs.boundingBox
            let left = Double(bb.minX).clamped01()
            let right = Double(bb.maxX).clamped01()
            let top0 = Double(1 - bb.maxY).clamped01()
            let bottom0 = Double(1 - bb.minY).clamped01()
            return [
                "label": top.identifier,
                "confidence": Double(top.confidence),
                "left": left,
                "top": top0,
                "right": right,
                "bottom": bottom0,
            ]
        }
    }

    // MARK: - Helpers

    private static func makePixelBuffer(
        bytes: Data, width: Int, height: Int, bytesPerRow: Int
    ) -> CVPixelBuffer? {
        var pixelBuffer: CVPixelBuffer?
        let attrs: [String: Any] = [
            kCVPixelBufferIOSurfacePropertiesKey as String: [:] as [String: Any],
        ]
        let status = CVPixelBufferCreate(
            kCFAllocatorDefault, width, height, kCVPixelFormatType_32BGRA,
            attrs as CFDictionary, &pixelBuffer
        )
        guard status == kCVReturnSuccess, let buffer = pixelBuffer else { return nil }

        CVPixelBufferLockBaseAddress(buffer, [])
        defer { CVPixelBufferUnlockBaseAddress(buffer, []) }
        guard let dest = CVPixelBufferGetBaseAddress(buffer) else { return nil }
        let destBytesPerRow = CVPixelBufferGetBytesPerRow(buffer)
        bytes.withUnsafeBytes { srcPtr in
            guard let srcBase = srcPtr.baseAddress else { return }
            for row in 0..<height {
                let srcRow = srcBase.advanced(by: row * bytesPerRow)
                let destRow = dest.advanced(by: row * destBytesPerRow)
                memcpy(destRow, srcRow, min(bytesPerRow, destBytesPerRow))
            }
        }
        return buffer
    }

    private static func readOrientation(source: CGImageSource) -> CGImagePropertyOrientation {
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
        frameStateQueue.sync { frameBusy = false }
    }

    private static let modelName = "ObjectDetector"
}

private extension Double {
    func clamped01() -> Double { Swift.min(Swift.max(self, 0), 1) }
}
