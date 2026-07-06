import 'dart:typed_data';

import 'package:document_scan/document_scan.dart' as ds;
import 'package:image/image.dart' as img;

import '../error/failures.dart';
import '../error/result.dart';
import '../models/document_corners.dart';
import '../models/normalized_corners.dart';
import '../platform/corner_detector.dart';

/// The app's document corner detection, powered by our own `document_scan`
/// package.
///
/// This is the single implementation of [CornerDetector]: it owns a
/// [ds.DocumentDetector] and delegates every detection to the package — there is
/// no native channel of the app's own involved. Callers (the realtime pipeline,
/// the still-image cropper) depend only on the [CornerDetector] interface, so
/// this class is where — and the only place where — the app is coupled to the
/// package. Swapping the engine later means changing just this file.
///
/// It reconciles the package's shape with the app's two corner contracts:
/// * **Realtime frames** → the package returns normalized 0..1 corners, exactly
///   what [NormalizedCorners] wants, so it's a field-for-field map (the frame
///   hot path stays allocation-light and returns `null` on any miss).
/// * **Still images** → the package returns normalized corners, but the app's
///   [DocumentCorners] contract is in **pixel** space, so this decodes the
///   image's dimensions and converts via the package's `toPixels`.
class DocumentScanCornerDetector implements CornerDetector {
  DocumentScanCornerDetector({ds.DocumentDetector? detector})
    : _detector = detector ?? ds.DocumentDetector();

  final ds.DocumentDetector _detector;

  @override
  Future<Result<DocumentCorners?>> detectCorners({
    required String imagePath,
  }) async {
    return Result.guard(
      () async {
        final corners = await _detector.detect(ds.ScanInput.file(imagePath));
        if (corners == null) return null;

        // The package gives normalized corners; the still-image contract is in
        // pixels, so map through the decoded image size. Decoding just the
        // header would be ideal, but `image` decodes fully — acceptable here as
        // this is the (non-realtime) still path.
        final decoded = await img.decodeImageFile(imagePath);
        if (decoded == null) return null;
        final px = corners.toPixels(decoded.width, decoded.height);
        return DocumentCorners(
          topLeft: px[0],
          topRight: px[1],
          bottomRight: px[2],
          bottomLeft: px[3],
        );
      },
      onError: (e) =>
          NativeChannelFailure('Document detection failed: $e'),
    );
  }

  @override
  Future<NormalizedCorners?> detectCornersFromFrame({
    required int width,
    required int height,
    required int rotation,
    Uint8List? bytes,
    int bytesPerRow = 0,
    Uint8List? yBytes,
    Uint8List? uBytes,
    Uint8List? vBytes,
    int yRowStride = 0,
    int uvRowStride = 0,
    int uvPixelStride = 1,
    String format = 'bgra',
  }) async {
    final input = ds.ScanInput.cameraFrame(
      width: width,
      height: height,
      format: format == 'yuv420'
          ? ds.ScanImageFormat.yuv420
          : ds.ScanImageFormat.bgra8888,
      rotation: rotation,
      bytes: bytes,
      bytesPerRow: bytesPerRow,
      yBytes: yBytes,
      uBytes: uBytes,
      vBytes: vBytes,
      yRowStride: yRowStride,
      uvRowStride: uvRowStride,
      uvPixelStride: uvPixelStride,
    );

    // Per-frame hot path: swallow any error into a dropped frame (null),
    // matching the interface contract.
    try {
      final corners = await _detector.detect(input);
      if (corners == null) return null;
      return NormalizedCorners(
        topLeft: corners.topLeft,
        topRight: corners.topRight,
        bottomRight: corners.bottomRight,
        bottomLeft: corners.bottomLeft,
      );
    } catch (_) {
      return null;
    }
  }
}
