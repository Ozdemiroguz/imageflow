import 'dart:io';
import 'dart:math' as math;

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:uuid/uuid.dart';

import '../../../../core/enums/processing_type.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/error/result.dart';
import '../../../../core/models/face_geometry.dart';
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
        var detection = await _contentDetector.detect(
          imagePath: workingPath,
          preferredType: preferredType,
        );

        if (capturedWithFrontCamera == true &&
            hasMirroredExifOrientation &&
            detection.type == ProcessingType.document) {
          await _flipImageHorizontallyInPlace(workingPath);
          final correctedDetection = await _contentDetector.detect(
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
        final faceRects = <FaceRect>[];
        final faceContours = <List<ContourPoint>>[];
        String? pdfPath;

        if (detection.hasFaces) {
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
        } else if (detection.type == ProcessingType.document) {
          // --- Document flow: crop + eco filter + PDF (only if text found) ---
          pdfPath = await _runDocumentPipeline(
            id: id,
            workingPath: workingPath,
            processedPath: processedPath,
            recognizedText: detection.recognizedText,
            appliedRotation: detection.appliedRotation,
            generatePdf: (detection.recognizedText?.text ?? '').isNotEmpty,
            onProgress: onProgress,
          );
        } else {
          // --- Fallback: no face, no text — just copy working copy ---
          await File(workingPath).copy(processedPath);
        }

        final type = detection.type ?? ProcessingType.document;
        final result = await _buildResult(
          id: id,
          type: type,
          originalPath: originalPath,
          processedPath: processedPath,
          pdfPath: pdfPath,
          extractedText: type == ProcessingType.document
              ? detection.recognizedText?.text
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
        final pdfPath = await _runDocumentPipeline(
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
          pdfPath: pdfPath,
          extractedText: extractedText,
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
  Future<String?> _runDocumentPipeline({
    required String id,
    required String workingPath,
    required String processedPath,
    required RecognizedTextData? recognizedText,
    required int appliedRotation,
    required bool generatePdf,
    ProgressCallback? onProgress,
  }) async {
    onProgress?.call(ProcessingStep.correctingPerspective);
    await _documentCrop.processDocument(
      sourcePath: workingPath,
      targetPath: processedPath,
      recognizedText: recognizedText,
    );

    await _restoreDocumentOrientation(
      imagePath: processedPath,
      appliedRotationDegrees: appliedRotation,
    );

    if (!generatePdf) return null;

    onProgress?.call(ProcessingStep.generatingPdf);
    final pdfPath = _fileService.pdfFilePath(id);
    await _generatePdf(imagePath: processedPath, pdfPath: pdfPath);
    return pdfPath;
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

    final reverseRotation = (360 - normalizedRotation) % 360;
    if (reverseRotation == 0) return;

    await ImageUtils.rotateInPlace(imagePath, degrees: reverseRotation);
  }

  Future<void> _flipImageHorizontallyInPlace(String imagePath) =>
      ImageUtils.flipHorizontalInPlace(imagePath);

  Future<bool> _hasMirroredExifOrientation(String imagePath) =>
      ImageUtils.hasMirroredExifOrientation(imagePath);
}
