import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

import '../../../../core/enums/processing_type.dart';
import '../../../../core/models/detection_result.dart';
import '../../../../core/utils/image_utils.dart';
import '../../../../core/utils/log.dart';

/// Handles EXIF orientation fix, face/text detection, and rotation fallback.
///
/// Pipeline:
/// 1. Normalize EXIF orientation (bake into pixels)
/// 2. Try face detection → if found, return
/// 3. Try text detection → if found, return
/// 4. If nothing found, rotate 90°/180°/270° and retry detection
/// 5. If still nothing, return empty result with document type
class ContentDetectionService {
  const ContentDetectionService({this.routingMaxDimension = 1600});

  static const _tag = 'ContentDetection';
  final int routingMaxDimension;

  /// Normalize EXIF orientation and detect content.
  ///
  /// [imagePath] is modified in-place (EXIF baked, possibly rotated).
  /// [preferredType] skips the other detection if set.
  Future<DetectionResult> detect({
    required String imagePath,
    ProcessingType? preferredType,
  }) async {
    // Step 1: Bake EXIF orientation into pixels
    await ImageUtils.normalizeOrientation(imagePath);

    final faceDetector = preferredType == ProcessingType.document
        ? null
        : FaceDetector(
            options: FaceDetectorOptions(
              performanceMode: FaceDetectorMode.accurate,
              enableContours: true,
              minFaceSize: 0.1,
            ),
          );
    final textRecognizer = preferredType == ProcessingType.face
        ? null
        : TextRecognizer();

    try {
      // Step 2: Try detection at original orientation (0°)
      final original = await _detectAtCurrentOrientation(
        imagePath,
        preferredType,
        faceDetector: faceDetector,
        textRecognizer: textRecognizer,
      );
      if (original.hasContent) return original;

      // Step 3: Rotation fallback — try 90°, 180°, 270°
      Log.debug('No content at 0°. Trying rotation fallback...', tag: _tag);

      for (final degrees in [90, 180, 270]) {
        await ImageUtils.rotateInPlace(imagePath, degrees: degrees);

        final rotated = await _detectAtCurrentOrientation(
          imagePath,
          preferredType,
          faceDetector: faceDetector,
          textRecognizer: textRecognizer,
        );
        if (rotated.hasContent) {
          Log.info('Content found at $degrees° rotation.', tag: _tag);

          // Keep the file in the rotated orientation so detection
          // coordinates match the pixel data for downstream processing.
          return DetectionResult(
            type: rotated.type,
            faces: rotated.faces,
            recognizedText: rotated.recognizedText,
            appliedRotation: degrees,
          );
        }

        // Rotate back before trying next angle
        await ImageUtils.rotateInPlace(imagePath, degrees: 360 - degrees);
      }

      Log.info('No content found at any rotation.', tag: _tag);
      return const DetectionResult(type: null);
    } finally {
      await faceDetector?.close();
      await textRecognizer?.close();
    }
  }

  /// Fast routing pass (downscaled) + full quality detect on source image.
  Future<DetectionResult> _detectAtCurrentOrientation(
    String imagePath,
    ProcessingType? preferredType, {
    required FaceDetector? faceDetector,
    required TextRecognizer? textRecognizer,
  }) async {
    if (preferredType != null) {
      return _detectFullQuality(
        imagePath: imagePath,
        type: preferredType,
        faceDetector: faceDetector,
        textRecognizer: textRecognizer,
      );
    }

    final routedType =
        await ImageUtils.withPreparedMlInputPath<ProcessingType?>(
          sourcePath: imagePath,
          maxDimension: routingMaxDimension,
          quality: 86,
          run: (mlPath) async {
            final inputImage = InputImage.fromFilePath(mlPath);

            // Fast face routing
            if ((preferredType == ProcessingType.face ||
                    preferredType == null) &&
                faceDetector != null) {
              final faces = await faceDetector.processImage(inputImage);
              if (faces.isNotEmpty) {
                return ProcessingType.face;
              }
            }

            // Fast text routing
            if ((preferredType == ProcessingType.document ||
                    preferredType == null) &&
                textRecognizer != null) {
              final text = await textRecognizer.processImage(inputImage);
              if (text.text.trim().isNotEmpty) {
                return ProcessingType.document;
              }
            }

            return null;
          },
        );

    if (routedType == null) {
      return const DetectionResult(type: null);
    }

    return _detectFullQuality(
      imagePath: imagePath,
      type: routedType,
      faceDetector: faceDetector,
      textRecognizer: textRecognizer,
    );
  }

  Future<DetectionResult> _detectFullQuality({
    required String imagePath,
    required ProcessingType type,
    required FaceDetector? faceDetector,
    required TextRecognizer? textRecognizer,
  }) async {
    final fullInputImage = InputImage.fromFilePath(imagePath);
    switch (type) {
      case ProcessingType.face:
        if (faceDetector == null) return const DetectionResult(type: null);
        final faces = await faceDetector.processImage(fullInputImage);
        if (faces.isNotEmpty) {
          Log.debug('Found ${faces.length} face(s)', tag: _tag);
          return DetectionResult(type: ProcessingType.face, faces: faces);
        }
        return const DetectionResult(type: null);
      case ProcessingType.document:
        if (textRecognizer == null) return const DetectionResult(type: null);
        final text = await textRecognizer.processImage(fullInputImage);
        if (text.text.isNotEmpty) {
          Log.debug(
            'Found ${text.blocks.length} text block(s), '
            'length=${text.text.length}',
            tag: _tag,
          );
          return DetectionResult(
            type: ProcessingType.document,
            recognizedText: text,
          );
        }
        return const DetectionResult(type: null);
    }
  }
}
