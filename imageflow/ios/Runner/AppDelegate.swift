import Flutter
import PDFKit
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)
    CornerDetectionHandlerV2.register(with: self.registrar(forPlugin: "CornerDetectionHandlerV2")!)
    PdfExternalOpenHandler.register(with: self.registrar(forPlugin: "PdfExternalOpenHandler")!)
    PdfRasterizeHandler.register(with: self.registrar(forPlugin: "PdfRasterizeHandler")!)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}

final class PdfExternalOpenHandler: NSObject, FlutterPlugin, UIDocumentInteractionControllerDelegate {
  private var documentController: UIDocumentInteractionController?

  static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(
      name: "com.oguzhan.imageflow/pdf_external",
      binaryMessenger: registrar.messenger()
    )
    let instance = PdfExternalOpenHandler()
    registrar.addMethodCallDelegate(instance, channel: channel)
  }

  func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard call.method == "openPdf" else {
      result(FlutterMethodNotImplemented)
      return
    }

    guard let args = call.arguments as? [String: Any],
          let path = args["path"] as? String,
          !path.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
      result(
        FlutterError(
          code: "INVALID_ARGS",
          message: "path required",
          details: nil
        )
      )
      return
    }

    openPdf(path: path, result: result)
  }

  private func openPdf(path: String, result: @escaping FlutterResult) {
    let fileUrl = URL(fileURLWithPath: path)
    guard FileManager.default.fileExists(atPath: fileUrl.path) else {
      result(
        FlutterError(
          code: "FILE_NOT_FOUND",
          message: "PDF file could not be found.",
          details: nil
        )
      )
      return
    }

    // Reuse the controller if the URL hasn't changed to avoid re-initialising
    // UIDocumentInteractionController on every call (first-time init can take
    // ~500 ms while the system loads the app list, visibly blocking the UI).
    if documentController?.url != fileUrl {
      let controller = UIDocumentInteractionController(url: fileUrl)
      controller.uti = "com.adobe.pdf"
      controller.delegate = self
      documentController = controller
    } else {
      documentController?.url = fileUrl
    }

    guard let controller = documentController else {
      result(FlutterError(code: "OPEN_FAILED", message: "No active view controller.", details: nil))
      return
    }

    guard let viewController = topViewController() else {
      result(
        FlutterError(
          code: "OPEN_FAILED",
          message: "No active view controller.",
          details: nil
        )
      )
      return
    }

    // Defer to the next run-loop tick so the Flutter engine can render the
    // loading overlay before the system app-list scan blocks the main thread.
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.10) { [weak self] in
      guard self != nil else { return }

      let opened = controller.presentOpenInMenu(
        from: viewController.view.bounds,
        in: viewController.view,
        animated: true
      )

      if !opened {
        let previewOpened = controller.presentPreview(animated: true)
        if !previewOpened {
          result(
            FlutterError(
              code: "PDF_APP_NOT_FOUND",
              message: "No external PDF viewer found on device.",
              details: nil
            )
          )
          return
        }
      }

      result(true)
    }
  }

  func documentInteractionControllerViewControllerForPreview(
    _ controller: UIDocumentInteractionController
  ) -> UIViewController {
    topViewController() ?? UIViewController()
  }

  private func topViewController(base: UIViewController? = nil) -> UIViewController? {
    let root: UIViewController? = {
      if let base {
        return base
      }
      if #available(iOS 13.0, *) {
        let scene = UIApplication.shared.connectedScenes
          .compactMap { $0 as? UIWindowScene }
          .first(where: { $0.activationState == .foregroundActive })
        return scene?.windows.first(where: { $0.isKeyWindow })?.rootViewController
      }
      return UIApplication.shared.keyWindow?.rootViewController
    }()

    if let nav = root as? UINavigationController {
      return topViewController(base: nav.visibleViewController)
    }
    if let tab = root as? UITabBarController {
      return topViewController(base: tab.selectedViewController)
    }
    if let presented = root?.presentedViewController {
      return topViewController(base: presented)
    }
    return root
  }
}

final class PdfRasterizeHandler: NSObject, FlutterPlugin {
  static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(
      name: "com.oguzhan.imageflow/pdf_raster",
      binaryMessenger: registrar.messenger()
    )
    let instance = PdfRasterizeHandler()
    registrar.addMethodCallDelegate(instance, channel: channel)
  }

  func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard call.method == "rasterizePdf" else {
      result(FlutterMethodNotImplemented)
      return
    }

    guard let args = call.arguments as? [String: Any],
          let path = args["path"] as? String,
          !path.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
      result(
        FlutterError(
          code: "INVALID_ARGS",
          message: "path required",
          details: nil
        )
      )
      return
    }

    let dpi = (args["dpi"] as? NSNumber)?.doubleValue ?? 144.0
    rasterize(path: path, dpi: dpi, result: result)
  }

  private func rasterize(path: String, dpi: Double, result: @escaping FlutterResult) {
    DispatchQueue.global(qos: .userInitiated).async {
      let fileUrl = URL(fileURLWithPath: path)
      guard FileManager.default.fileExists(atPath: fileUrl.path) else {
        DispatchQueue.main.async {
          result(
            FlutterError(
              code: "FILE_NOT_FOUND",
              message: "PDF file could not be found.",
              details: nil
            )
          )
        }
        return
      }

      guard let document = PDFDocument(url: fileUrl) else {
        DispatchQueue.main.async {
          result(
            FlutterError(
              code: "RASTER_FAILED",
              message: "Unable to read PDF.",
              details: nil
            )
          )
        }
        return
      }

      let pageCount = document.pageCount
      if pageCount == 0 {
        DispatchQueue.main.async {
          result([FlutterStandardTypedData]())
        }
        return
      }

      let scale = max(dpi / 72.0, 1.0)
      let scaleFactor = CGFloat(scale)
      var pages = [FlutterStandardTypedData]()
      pages.reserveCapacity(pageCount)

      for index in 0..<pageCount {
        autoreleasepool {
          guard let page = document.page(at: index) else { return }
          let bounds = page.bounds(for: .mediaBox)
          let size = CGSize(
            width: max(bounds.width * scaleFactor, 1.0),
            height: max(bounds.height * scaleFactor, 1.0)
          )

          let format = UIGraphicsImageRendererFormat.default()
          format.scale = 1
          format.opaque = true

          let renderer = UIGraphicsImageRenderer(size: size, format: format)
          let image = renderer.image { ctx in
            UIColor.white.setFill()
            ctx.fill(CGRect(origin: .zero, size: size))

            let cg = ctx.cgContext
            cg.saveGState()
            cg.translateBy(x: 0, y: size.height)
            cg.scaleBy(x: scaleFactor, y: -scaleFactor)
            page.draw(with: .mediaBox, to: cg)
            cg.restoreGState()
          }

          guard let data = image.pngData() else { return }
          pages.append(FlutterStandardTypedData(bytes: data))
        }
      }

      DispatchQueue.main.async {
        result(pages)
      }
    }
  }
}
