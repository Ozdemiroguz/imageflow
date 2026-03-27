import 'dart:io';
import 'dart:isolate';
import 'dart:math' as math;

import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:image/image.dart' as img;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:uuid/uuid.dart';

import '../../../../core/enums/processing_type.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/error/result.dart';
import '../services/content_detection_service.dart';
import '../services/document_crop_service.dart';
import '../../../../core/services/file_service.dart';
import '../../../../core/utils/face_mask_utils.dart';
import '../../../../core/utils/image_utils.dart';
import '../../../../core/utils/log.dart';
import '../../domain/entities/processing_result.dart';
import '../../domain/entities/processing_step.dart';
import '../../domain/repositories/processing_repository.dart';

class ProcessingRepositoryImpl implements ProcessingRepository {
  const ProcessingRepositoryImpl({
    required FileService fileService,
    required ContentDetectionService contentDetectionService,
    required DocumentCropService documentCropService,
  }) : _fileService = fileService,
       _contentDetection = contentDetectionService,
       _documentCrop = documentCropService;

  final FileService _fileService;
  final ContentDetectionService _contentDetection;
  final DocumentCropService _documentCrop;

  static const _uuid = Uuid();

  @override
  Future<Result<ProcessingResult>> processImage({
    required String imagePath,
    ProcessingType? preferredType,
    ProgressCallback? onProgress,
    bool? capturedWithFrontCamera,
  }) => Result.guard(
    () async {
      final id = _uuid.v4();

      // Step 1: Copy original to app storage
      onProgress?.call(ProcessingStep.copying);
      final originalPath = _fileService.originalFilePath(id);
      await File(imagePath).copy(originalPath);
      final hasMirroredExifOrientation = capturedWithFrontCamera == true
          ? await _hasMirroredExifOrientation(originalPath)
          : false;

      // Step 2: EXIF fix + detect content (with rotation fallback)
      // Use a working copy so detection rotation doesn't alter the original.
      onProgress?.call(ProcessingStep.detectingFaces);
      final workingPath = _fileService.processedFilePath('${id}_work');
      await File(originalPath).copy(workingPath);
      try {
        var detection = await _contentDetection.detect(
          imagePath: workingPath,
          preferredType: preferredType,
        );

        if (capturedWithFrontCamera == true &&
            hasMirroredExifOrientation &&
            detection.type == ProcessingType.document) {
          await _flipImageHorizontallyInPlace(workingPath);
          final correctedDetection = await _contentDetection.detect(
            imagePath: workingPath,
            preferredType: ProcessingType.document,
          );
          if (correctedDetection.type == ProcessingType.document) {
            detection = correctedDetection;
            Log.info(
              'Applied front-camera mirror correction for document flow.',
              tag: 'Processing',
            );
          } else {
            Log.warning(
              'Front-camera mirror correction re-detect failed; '
              'continuing with initial detection.',
              tag: 'Processing',
            );
          }
        } else if (capturedWithFrontCamera == true &&
            detection.type == ProcessingType.document) {
          Log.info(
            'Front-camera document detected without mirrored EXIF; '
            'skipping horizontal flip correction.',
            tag: 'Processing',
          );
        }

        // No content detected at all → throw error
        if (detection.type == null) {
          throw const DetectionFailure(
            'No face or text detected in this image. '
            'Try a clearer photo with visible faces or text.',
          );
        }

        final processedPath = _fileService.processedFilePath(id);
        final faceRects = <({int left, int top, int width, int height})>[];
        final faceContours = <List<({int x, int y})>>[];
        String? pdfPath;

        if (detection.hasFaces) {
          // --- Face flow ---
          onProgress?.call(ProcessingStep.annotating);
          final rects = <({int left, int top, int width, int height})>[];
          final contours = <List<({int x, int y})>>[];

          for (final face in detection.faces!) {
            final r = face.boundingBox;
            final left = r.left.floor();
            final top = r.top.floor();
            final right = r.right.ceil();
            final bottom = r.bottom.ceil();
            rects.add((
              left: left,
              top: top,
              width: math.max(1, right - left),
              height: math.max(1, bottom - top),
            ));

            final faceContour = face.contours[FaceContourType.face];
            if (faceContour != null) {
              contours.add(
                faceContour.points
                    .map((p) => (x: p.x.round(), y: p.y.round()))
                    .toList(),
              );
            } else {
              contours.add(const []);
            }
          }

          faceRects.addAll(rects);
          faceContours.addAll(contours);
          await _annotateFaces(workingPath, processedPath, rects, contours);
        } else if (detection.type == ProcessingType.document) {
          // --- Document flow: text-block crop + eco filter ---
          onProgress?.call(ProcessingStep.correctingPerspective);
          await _documentCrop.processDocument(
            sourcePath: workingPath,
            targetPath: processedPath,
            recognizedText: detection.recognizedText,
          );

          await _restoreDocumentOrientation(
            imagePath: processedPath,
            appliedRotationDegrees: detection.appliedRotation,
          );

          // Generate PDF (only if text was found)
          final extractedText = detection.recognizedText?.text ?? '';
          if (extractedText.isNotEmpty) {
            onProgress?.call(ProcessingStep.generatingPdf);
            pdfPath = _fileService.pdfFilePath(id);
            await _generatePdf(imagePath: processedPath, pdfPath: pdfPath);
          }
        } else {
          // --- Fallback: no face, no text — just copy working copy ---
          await File(workingPath).copy(processedPath);
        }

        // Generate thumbnail
        onProgress?.call(ProcessingStep.generatingThumbnail);
        final thumbnailPath = _fileService.thumbnailFilePath(id);
        await ImageUtils.generateThumbnail(
          sourcePath: processedPath,
          targetPath: thumbnailPath,
        );

        // Save to history (relative paths for persistence)
        onProgress?.call(ProcessingStep.saving);
        final fileSizeBytes = await File(processedPath).length();

        final type = detection.type ?? ProcessingType.document;

        final result = ProcessingResult(
          id: id,
          type: type,
          originalImagePath: originalPath,
          processedImagePath: processedPath,
          thumbnailPath: thumbnailPath,
          fileSizeBytes: fileSizeBytes,
          createdAt: DateTime.now(),
          facesDetected: faceRects.length,
          faceRects: faceRects,
          faceContours: faceContours,
          extractedText: type == ProcessingType.document
              ? detection.recognizedText?.text
              : null,
          pdfPath: pdfPath,
        );

        onProgress?.call(ProcessingStep.complete);
        return result;
      } finally {
        await _safeDeleteFile(workingPath);
      }
    },
    onError: (e) =>
        _mapProcessingFailure(e, fallbackMessage: 'Processing failed.'),
    onLog: (e, st) => Log.error(
      'Processing failed',
      error: e,
      stackTrace: st,
      tag: 'Processing',
    ),
  );

  @override
  Future<Result<ProcessingResult>> processImageExternal({
    required String imagePath,
    ProgressCallback? onProgress,
  }) => Result.guard(
    () async {
      final id = _uuid.v4();

      // Step 1: Copy original to app storage
      onProgress?.call(ProcessingStep.copying);
      final originalPath = _fileService.originalFilePath(id);
      await File(imagePath).copy(originalPath);

      // Step 2: Detect text (document-only, with rotation fallback)
      // Use a working copy so detection rotation doesn't alter the original.
      onProgress?.call(ProcessingStep.detectingText);
      final workingPath = _fileService.processedFilePath('${id}_work');
      await File(originalPath).copy(workingPath);
      try {
        final detection = await _contentDetection.detect(
          imagePath: workingPath,
          preferredType: ProcessingType.document,
        );

        final extractedText = detection.recognizedText?.text ?? '';
        if (extractedText.isEmpty) {
          throw const DetectionFailure(
            'No text detected in this image. '
            'Try a clearer photo with visible text.',
          );
        }

        // Step 3+4: Text-block crop + eco filter
        onProgress?.call(ProcessingStep.correctingPerspective);
        final processedPath = _fileService.processedFilePath(id);
        await _documentCrop.processDocument(
          sourcePath: workingPath,
          targetPath: processedPath,
          recognizedText: detection.recognizedText,
        );

        await _restoreDocumentOrientation(
          imagePath: processedPath,
          appliedRotationDegrees: detection.appliedRotation,
        );

        // Step 5: Generate PDF
        onProgress?.call(ProcessingStep.generatingPdf);
        final pdfPath = _fileService.pdfFilePath(id);
        await _generatePdf(imagePath: processedPath, pdfPath: pdfPath);

        // Thumbnail
        onProgress?.call(ProcessingStep.generatingThumbnail);
        final thumbnailPath = _fileService.thumbnailFilePath(id);
        await ImageUtils.generateThumbnail(
          sourcePath: processedPath,
          targetPath: thumbnailPath,
        );

        // Save to history
        onProgress?.call(ProcessingStep.saving);
        final fileSizeBytes = await File(processedPath).length();

        final result = ProcessingResult(
          id: id,
          type: ProcessingType.document,
          originalImagePath: originalPath,
          processedImagePath: processedPath,
          thumbnailPath: thumbnailPath,
          fileSizeBytes: fileSizeBytes,
          createdAt: DateTime.now(),
          extractedText: extractedText,
          pdfPath: pdfPath,
        );

        onProgress?.call(ProcessingStep.complete);
        return result;
      } finally {
        await _safeDeleteFile(workingPath);
      }
    },
    onError: (e) => _mapProcessingFailure(
      e,
      fallbackMessage: 'External processing failed.',
    ),
    onLog: (e, st) => Log.error(
      'External processing failed',
      error: e,
      stackTrace: st,
      tag: 'Processing',
    ),
  );

  /// Preserves domain-specific failures (e.g. [DetectionFailure]) so
  /// presentation can render the correct UI state.
  Failure _mapProcessingFailure(
    Object error, {
    required String fallbackMessage,
  }) {
    if (error is Failure) return error;
    return ProcessingFailure(fallbackMessage);
  }

  Future<void> _safeDeleteFile(String path) async {
    final file = File(path);
    try {
      // ignore: avoid_slow_async_io
      if (await file.exists()) {
        // ignore: avoid_slow_async_io
        await file.delete();
      }
    } catch (e, st) {
      Log.warning('Failed to delete temp file: $path', tag: 'Processing');
      Log.error(
        'Temp cleanup error',
        error: e,
        stackTrace: st,
        tag: 'Processing',
      );
    }
  }

  /// Crop face regions, apply grayscale filter via contour mask, composite back.
  Future<void> _annotateFaces(
    String sourcePath,
    String targetPath,
    List<({int left, int top, int width, int height})> rects,
    List<List<({int x, int y})>> contours,
  ) async {
    await Isolate.run(() {
      final bytes = File(sourcePath).readAsBytesSync();
      final image = img.decodeImage(bytes);
      if (image == null) return;

      for (var i = 0; i < rects.length; i++) {
        final rect = rects[i];
        final contour = contours[i];
        final borderColor = img.ColorRgba8(0, 230, 118, 200);

        var faceLeft = rect.left;
        var faceTop = rect.top;
        var faceRight = rect.left + rect.width;
        var faceBottom = rect.top + rect.height;
        if (contour.isNotEmpty) {
          var contourMinX = contour.first.x;
          var contourMinY = contour.first.y;
          var contourMaxX = contour.first.x;
          var contourMaxY = contour.first.y;
          for (final p in contour) {
            if (p.x < contourMinX) contourMinX = p.x;
            if (p.y < contourMinY) contourMinY = p.y;
            if (p.x > contourMaxX) contourMaxX = p.x;
            if (p.y > contourMaxY) contourMaxY = p.y;
          }
          faceLeft = math.min(faceLeft, contourMinX);
          faceTop = math.min(faceTop, contourMinY);
          faceRight = math.max(faceRight, contourMaxX + 1);
          faceBottom = math.max(faceBottom, contourMaxY + 1);
        }

        // Clamp to image bounds
        final x = faceLeft.clamp(0, image.width - 1);
        final y = faceTop.clamp(0, image.height - 1);
        final w = (faceRight - x).clamp(1, image.width - x);
        final h = (faceBottom - y).clamp(1, image.height - y);

        // Crop → grayscale
        final cropped = img.copyCrop(image, x: x, y: y, width: w, height: h);
        final gray = img.grayscale(cropped);

        if (contour.isNotEmpty) {
          // Use real face contour polygon as mask.
          FaceMaskUtils.applyContourGrayMaskInPlace(
            image: image,
            grayCrop: gray,
            cropLeft: x,
            cropTop: y,
            cropWidth: w,
            cropHeight: h,
            contour: contour,
          );

          // Draw contour border
          for (var j = 0; j < contour.length; j++) {
            final p1 = contour[j];
            final p2 = contour[(j + 1) % contour.length];
            img.drawLine(
              image,
              x1: p1.x,
              y1: p1.y,
              x2: p2.x,
              y2: p2.y,
              color: borderColor,
              thickness: 3,
            );
          }
        } else {
          // Fallback: oval mask from bounding box
          final ovalMasked = FaceMaskUtils.buildOvalMaskedGrayImage(cropped);
          for (var py = 0; py < h; py++) {
            for (var px = 0; px < w; px++) {
              final pixel = ovalMasked.getPixel(px, py);
              if (pixel.a > 0) {
                image.setPixel(x + px, y + py, pixel);
              }
            }
          }

          // Keep border style close to contour by drawing an oval polyline.
          final cx = w / 2;
          final cy = h / 2;
          final centerX = x + cx;
          final centerY = y + cy;
          final radiusX = w / 2;
          final radiusY = h / 2;
          const segments = 64;
          for (var s = 0; s < segments; s++) {
            final t1 = (2 * math.pi * s) / segments;
            final t2 = (2 * math.pi * (s + 1)) / segments;
            final p1x = (centerX + radiusX * math.cos(t1)).round();
            final p1y = (centerY + radiusY * math.sin(t1)).round();
            final p2x = (centerX + radiusX * math.cos(t2)).round();
            final p2y = (centerY + radiusY * math.sin(t2)).round();

            img.drawLine(
              image,
              x1: p1x,
              y1: p1y,
              x2: p2x,
              y2: p2y,
              color: borderColor,
              thickness: 3,
            );
          }
        }
      }

      File(targetPath).writeAsBytesSync(img.encodeJpg(image, quality: 90));
    });
  }

  /// Generate a PDF from the processed document image.
  Future<void> _generatePdf({
    required String imagePath,
    required String pdfPath,
  }) async {
    final imageBytes = await File(imagePath).readAsBytes();

    final doc = pw.Document();
    final pdfImage = pw.MemoryImage(imageBytes);

    // Page 1: Full-page scanned image
    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(24),
        build: (context) =>
            pw.Center(child: pw.Image(pdfImage, fit: pw.BoxFit.contain)),
      ),
    );

    final pdfBytes = await doc.save();
    await File(pdfPath).writeAsBytes(pdfBytes);
  }

  Future<void> _restoreDocumentOrientation({
    required String imagePath,
    required int appliedRotationDegrees,
  }) async {
    final normalizedRotation = appliedRotationDegrees % 360;
    if (normalizedRotation == 0) return;

    final reverseRotation = (360 - normalizedRotation) % 360;
    if (reverseRotation == 0) return;

    await ImageUtils.rotateInPlace(imagePath, degrees: reverseRotation);
  }

  Future<void> _flipImageHorizontallyInPlace(String imagePath) =>
      ImageUtils.flipHorizontalInPlace(imagePath);

  Future<bool> _hasMirroredExifOrientation(String imagePath) =>
      ImageUtils.hasMirroredExifOrientation(imagePath);
}
