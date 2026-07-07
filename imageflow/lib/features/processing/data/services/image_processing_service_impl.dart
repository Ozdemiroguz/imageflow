import 'dart:io';
import 'dart:math' as math;

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:uuid/uuid.dart';

import '../../../../core/enums/processing_type.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/error/result.dart';
import '../../../../core/models/face_geometry.dart';
import '../../../../core/models/normalized_corners.dart';
import '../../domain/entities/recognized_text_data.dart';
import '../../../../core/services/file_service.dart';
import '../utils/image_utils.dart';
import '../../../../core/utils/log.dart';
import '../../domain/entities/processing_result.dart';
import '../../domain/entities/processing_step.dart';
import '../../domain/services/content_detector.dart';
import '../../domain/services/document_cropper.dart';
import '../../domain/services/face_annotator.dart';
import '../../domain/services/image_processing_service.dart';

class ImageProcessingServiceImpl implements ImageProcessingService {
  const ImageProcessingServiceImpl({
    required FileService fileService,
    required ContentDetector contentDetector,
    required DocumentCropper documentCropper,
    required FaceAnnotator faceAnnotator,
  }) : _fileService = fileService,
       _contentDetector = contentDetector,
       _documentCrop = documentCropper,
       _faceAnnotator = faceAnnotator;

  final FileService _fileService;
  final ContentDetector _contentDetector;
  final DocumentCropper _documentCrop;
  final FaceAnnotator _faceAnnotator;

  static const _uuid = Uuid();

  @override
  Future<Result<ProcessingResult>> processImage({
    required String imagePath,
    ProcessingType? preferredType,
    ProgressCallback? onProgress,
    bool? capturedWithFrontCamera,
    NormalizedCorners? corners,
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
        // If the user confirmed corners on the adjust screen, this is
        // definitively a document — force document detection so an ID card's
        // photo doesn't route the whole image into the face flow.
        final effectivePreferredType =
            corners != null ? ProcessingType.document : preferredType;
        // When the user supplied corners, they are in the upright (0°) space of
        // the working copy. The rotation fallback rotates that file in place to
        // hunt for text, which would move the pixels out from under those
        // corners and make the crop warp the wrong region — so disable it here.
        final allowRotationFallback = corners == null;
        var detection = await _contentDetector.detect(
          imagePath: workingPath,
          preferredType: effectivePreferredType,
          allowRotationFallback: allowRotationFallback,
        );

        if (capturedWithFrontCamera == true &&
            hasMirroredExifOrientation &&
            detection.type == ProcessingType.document) {
          await _flipImageHorizontallyInPlace(workingPath);
          final correctedDetection = await _contentDetector.detect(
            imagePath: workingPath,
            preferredType: ProcessingType.document,
            allowRotationFallback: allowRotationFallback,
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

        // When the user confirmed corners, treat it as a document no matter what
        // detection said (an ID card's face must not send it to the face flow,
        // and a text-less document must still be cropped).
        final forceDocument = corners != null;

        // No content detected at all → throw error (unless the user gave
        // corners, in which case we crop it as a document regardless).
        if (detection.type == null && !forceDocument) {
          throw const DetectionFailure(
            'No face or text detected in this image. '
            'Try a clearer photo with visible faces or text.',
          );
        }

        final processedPath = _fileService.processedFilePath(id);
        final faceRects = <FaceRect>[];
        final faceContours = <List<ContourPoint>>[];
        String? pdfPath;

        if (detection.hasFaces && !forceDocument) {
          // --- Face flow ---
          onProgress?.call(ProcessingStep.annotating);
          for (final face in detection.faces!) {
            final box = face.boundingBox;
            faceRects.add((
              left: box.left,
              top: box.top,
              width: math.max(1, box.right - box.left),
              height: math.max(1, box.bottom - box.top),
            ));
            faceContours.add(face.contour);
          }
          await _faceAnnotator.annotate(
            sourcePath: workingPath,
            targetPath: processedPath,
            rects: faceRects,
            contours: faceContours,
          );
        }

        String? refinedText;
        if ((forceDocument || !detection.hasFaces) &&
            (forceDocument || detection.type == ProcessingType.document)) {
          // --- Document flow: crop + eco filter + PDF (only if text found) ---
          final doc = await _runDocumentPipeline(
            id: id,
            workingPath: workingPath,
            processedPath: processedPath,
            recognizedText: detection.recognizedText,
            appliedRotation: detection.appliedRotation,
            generatePdf: (detection.recognizedText?.text ?? '').isNotEmpty,
            corners: corners,
            onProgress: onProgress,
          );
          pdfPath = doc.pdfPath;
          refinedText = doc.refinedText;
        } else if (!detection.hasFaces) {
          // --- Fallback: no face, no text — just copy working copy ---
          await File(workingPath).copy(processedPath);
        }

        final type = forceDocument
            ? ProcessingType.document
            : (detection.type ?? ProcessingType.document);
        final result = await _buildResult(
          id: id,
          type: type,
          originalPath: originalPath,
          processedPath: processedPath,
          pdfPath: pdfPath,
          // Prefer the post-crop OCR text (read from the clean, deskewed image);
          // fall back to the original-image OCR when the second pass was empty.
          extractedText: type == ProcessingType.document
              ? (refinedText ?? detection.recognizedText?.text)
              : null,
          faceRects: faceRects,
          faceContours: faceContours,
          onProgress: onProgress,
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
        final detection = await _contentDetector.detect(
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

        // Document pipeline: crop + eco filter + orientation + PDF.
        final processedPath = _fileService.processedFilePath(id);
        final doc = await _runDocumentPipeline(
          id: id,
          workingPath: workingPath,
          processedPath: processedPath,
          recognizedText: detection.recognizedText,
          appliedRotation: detection.appliedRotation,
          generatePdf: true,
          onProgress: onProgress,
        );

        final result = await _buildResult(
          id: id,
          type: ProcessingType.document,
          originalPath: originalPath,
          processedPath: processedPath,
          pdfPath: doc.pdfPath,
          // Prefer post-crop OCR text; fall back to the original-image text.
          extractedText: doc.refinedText ?? extractedText,
          onProgress: onProgress,
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

  /// Runs the document pipeline shared by both entry points: text-block crop +
  /// eco filter, orientation restore, then PDF generation when [generatePdf] is
  /// requested. Returns the generated PDF path, or null when none was produced.
  Future<({String? pdfPath, String? refinedText})> _runDocumentPipeline({
    required String id,
    required String workingPath,
    required String processedPath,
    required RecognizedTextData? recognizedText,
    required int appliedRotation,
    required bool generatePdf,
    NormalizedCorners? corners,
    ProgressCallback? onProgress,
  }) async {
    onProgress?.call(ProcessingStep.correctingPerspective);
    final cropOutcome = await _documentCrop.processDocument(
      sourcePath: workingPath,
      targetPath: processedPath,
      recognizedText: recognizedText,
      corners: corners,
    );

    await _restoreDocumentOrientation(
      imagePath: processedPath,
      appliedRotationDegrees: appliedRotation,
    );

    // Second OCR pass on the cropped + deskewed document: text is far more
    // legible on the clean image than on the raw (often skewed) photo, so this
    // gives better extracted text — especially for camera captures. Falls back
    // to the original-image OCR if this pass finds nothing, so it never loses
    // text we already had.
    //
    // Skip it when it provably can't help: if the crop only applied a
    // whole-image filter (no warp, no text-block crop) AND no rotation was
    // undone, the processed image is spatially identical to the one the first
    // detection pass already OCR'd — re-OCR would read the exact same layout.
    // This saves one OCR per such document (notably across a batch) with zero
    // change to the extracted text. Any real crop or rotation still re-OCRs.
    final canRefineText =
        cropOutcome == DocumentCropOutcome.geometryChanged ||
        appliedRotation % 360 != 0;
    final String? refinedText;
    if (canRefineText) {
      onProgress?.call(ProcessingStep.extractingText);
      refinedText = await _extractTextFromProcessed(processedPath);
    } else {
      refinedText = null;
    }

    if (!generatePdf) return (pdfPath: null, refinedText: refinedText);

    onProgress?.call(ProcessingStep.generatingPdf);
    final pdfPath = _fileService.pdfFilePath(id);
    await _generatePdf(imagePath: processedPath, pdfPath: pdfPath);
    return (pdfPath: pdfPath, refinedText: refinedText);
  }

  /// Runs an OCR-only pass on the cropped document and returns its text, or null
  /// if none is found (the caller keeps the original-image text in that case).
  Future<String?> _extractTextFromProcessed(String processedPath) async {
    try {
      final detection = await _contentDetector.detect(
        imagePath: processedPath,
        preferredType: ProcessingType.document,
        // This is an OCR-only read of the already-cropped, upright result. The
        // rotation fallback must stay OFF here: it would rotate processedPath in
        // place and leave it rotated, corrupting the final image the user sees
        // when the crop happens to have no OCR-readable text.
        allowRotationFallback: false,
      );
      final text = detection.recognizedText?.text;
      return (text != null && text.isNotEmpty) ? text : null;
    } catch (e) {
      Log.warning('Post-crop OCR failed ($e); keeping original text.',
          tag: 'Processing');
      return null;
    }
  }

  /// Generates the thumbnail, reads the final file size, and assembles the
  /// [ProcessingResult] — the tail shared by both entry points.
  Future<ProcessingResult> _buildResult({
    required String id,
    required ProcessingType type,
    required String originalPath,
    required String processedPath,
    required String? pdfPath,
    required String? extractedText,
    ProgressCallback? onProgress,
    List<FaceRect> faceRects = const [],
    List<List<ContourPoint>> faceContours = const [],
  }) async {
    onProgress?.call(ProcessingStep.generatingThumbnail);
    final thumbnailPath = _fileService.thumbnailFilePath(id);
    await ImageUtils.generateThumbnail(
      sourcePath: processedPath,
      targetPath: thumbnailPath,
    );

    onProgress?.call(ProcessingStep.saving);
    final fileSizeBytes = await File(processedPath).length();

    return ProcessingResult(
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
      extractedText: extractedText,
      pdfPath: pdfPath,
    );
  }

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
      // Best-effort temp cleanup; the working copy may already be gone.
      // ignore: avoid_slow_async_io
      if (await file.exists()) {
        // Async delete keeps cleanup off the UI isolate.
        // ignore: avoid_slow_async_io
        await file.delete();
      }
    } catch (e, st) {
      // Best-effort cleanup: a leftover temp file is harmless, so we log and
      // move on rather than failing the pipeline.
      Log.error(
        'Failed to delete temp file: $path',
        error: e,
        stackTrace: st,
        tag: 'Processing',
      );
    }
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

    // normalizedRotation is 1..359 here, so the reverse is always non-zero.
    final reverseRotation = (360 - normalizedRotation) % 360;
    await ImageUtils.rotateInPlace(imagePath, degrees: reverseRotation);
  }

  Future<void> _flipImageHorizontallyInPlace(String imagePath) =>
      ImageUtils.flipHorizontalInPlace(imagePath);

  Future<bool> _hasMirroredExifOrientation(String imagePath) =>
      ImageUtils.hasMirroredExifOrientation(imagePath);
}
