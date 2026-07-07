import 'dart:async';

import 'package:document_scan/document_scan.dart' as ds;
import 'package:get/get.dart';

import '../../../../core/models/normalized_corners.dart';
import '../../../../core/routes/app_routes.dart';

/// Drives the manual corner-adjustment screen.
///
/// On entry it detects the document's corners through the document_scan package
/// and shows them over the image for the user to confirm or drag. On confirm it
/// forwards the (possibly edited) corners to the processing route, which crops
/// with exactly those corners. If no document is detected it skips straight to
/// processing, preserving the fully-automatic path for faces / non-documents.
class CornerAdjustController extends GetxController {
  CornerAdjustController({ds.DocumentScanner? scanner})
    : _scanner = scanner ?? ds.DocumentScanner();

  final ds.DocumentScanner _scanner;

  late final String imagePath;
  bool? _capturedWithFrontCamera;

  /// The current corners (normalized 0..1), updated as the user drags. Null
  /// while detection is running or when no document was found.
  final corners = Rxn<NormalizedCorners>();

  /// Whether corner detection is still running.
  final isDetecting = true.obs;

  @override
  void onInit() {
    super.onInit();
    final args = Get.arguments;
    if (args is Map<String, dynamic>) {
      imagePath = args['imagePath']?.toString() ?? '';
      final flag = args['capturedWithFrontCamera'];
      _capturedWithFrontCamera = flag is bool ? flag : null;
    } else {
      imagePath = args?.toString() ?? '';
      _capturedWithFrontCamera = null;
    }
    unawaited(_detect());
  }

  Future<void> _detect() async {
    isDetecting.value = true;
    ds.DocumentCorners? detected;
    try {
      detected = await _scanner.detectCorners(ds.ScanInput.file(imagePath));
    } catch (_) {
      detected = null;
    }
    if (isClosed) return;

    if (detected == null) {
      // No document rectangle — nothing to adjust, go straight to processing.
      _goToProcessing(corners: null);
      return;
    }
    corners.value = detected.toNormalized();
    isDetecting.value = false;
  }

  /// Replaces one corner (called during a drag). [index] is 0=TL, 1=TR, 2=BR,
  /// 3=BL. Values are clamped to 0..1.
  void moveCorner(int index, ({double x, double y}) point) {
    final c = corners.value;
    if (c == null) return;
    final p = (x: point.x.clamp(0.0, 1.0), y: point.y.clamp(0.0, 1.0));
    corners.value = NormalizedCorners(
      topLeft: index == 0 ? p : c.topLeft,
      topRight: index == 1 ? p : c.topRight,
      bottomRight: index == 2 ? p : c.bottomRight,
      bottomLeft: index == 3 ? p : c.bottomLeft,
    );
  }

  /// Confirms the current corners and proceeds to processing.
  void confirm() => _goToProcessing(corners: corners.value);

  void _goToProcessing({required NormalizedCorners? corners}) {
    Get.offNamed(
      AppRoutes.processing,
      arguments: <String, dynamic>{
        'imagePath': imagePath,
        if (_capturedWithFrontCamera != null)
          'capturedWithFrontCamera': _capturedWithFrontCamera,
        'corners': ?corners,
      },
    );
  }
}
