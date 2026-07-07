import 'dart:typed_data';

import 'package:document_scan/document_scan.dart' as ds;

import '../models/normalized_corners.dart';
import '../platform/corner_detector.dart';

/// The app's realtime corner detection, powered by our own `document_scan`
/// package.
///
/// This is the single implementation of [CornerDetector]: it owns a
/// [ds.DocumentDetector] and delegates each frame to the package — there is no
/// native channel of the app's own involved. Callers (the realtime pipeline)
/// depend only on the [CornerDetector] interface, so this class is where — and
/// the only place where — the app is coupled to the package for realtime.
/// Swapping the engine later means changing just this file.
///
/// The package returns normalized 0..1 corners, exactly what [NormalizedCorners]
/// wants, so it's a field-for-field map; the frame hot path stays allocation-
/// light and returns `null` on any miss.
class DocumentScanCornerDetector implements CornerDetector {
  DocumentScanCornerDetector({ds.DocumentDetector? detector})
    : _detector = detector ?? ds.DocumentDetector();

  final ds.DocumentDetector _detector;

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
      return corners?.toNormalized();
    } catch (_) {
      return null;
    }
  }
}
