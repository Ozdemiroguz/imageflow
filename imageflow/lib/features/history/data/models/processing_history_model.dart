import 'package:hive_ce/hive.dart';

import '../../../../core/enums/processing_type.dart';
import '../../domain/entities/processing_history.dart';

part 'processing_history_model_type_model.dart';
part 'processing_history_model.g.dart';

@HiveType(typeId: 0)
class ProcessingHistoryModel extends HiveObject {
  ProcessingHistoryModel({
    required this.id,
    required this.originalImagePath,
    required this.processedImagePath,
    required this.type,
    required this.createdAt,
    required this.fileSizeBytes,
    this.thumbnailPath,
    this.pdfPath,
    this.extractedText,
    this.facesDetected = 0,
    this.faceRects = const [],
    this.faceContours = const [],
  });

  @HiveField(0)
  final String id;

  @HiveField(1)
  final String originalImagePath;

  @HiveField(2)
  final String processedImagePath;

  @HiveField(3)
  final ProcessingTypeModel type;

  @HiveField(4)
  final DateTime createdAt;

  @HiveField(5)
  final int fileSizeBytes;

  @HiveField(6)
  final String? thumbnailPath;

  @HiveField(7)
  final String? pdfPath;

  @HiveField(8)
  final String? extractedText;

  @HiveField(9, defaultValue: 0)
  final int facesDetected;

  @HiveField(10, defaultValue: [])
  final List<List<int>> faceRects;

  @HiveField(11, defaultValue: [])
  final List<List<List<int>>> faceContours;

  factory ProcessingHistoryModel.fromEntity(ProcessingHistory entity) {
    return ProcessingHistoryModel(
      id: entity.id,
      originalImagePath: entity.originalImagePath,
      processedImagePath: entity.processedImagePath,
      type: switch (entity.type) {
        ProcessingType.face => ProcessingTypeModel.face,
        ProcessingType.document => ProcessingTypeModel.document,
      },
      createdAt: entity.createdAt,
      fileSizeBytes: entity.fileSizeBytes,
      thumbnailPath: entity.thumbnailPath,
      pdfPath: entity.pdfPath,
      extractedText: entity.extractedText,
      facesDetected: entity.facesDetected,
      faceRects: entity.faceRects
          .map((r) => [r.left, r.top, r.width, r.height])
          .toList(growable: false),
      faceContours: entity.faceContours
          .map(
            (contour) => contour
                .map((p) => [p.x, p.y])
                .toList(growable: false),
          )
          .toList(growable: false),
    );
  }

  ProcessingHistory toEntity() {
    return ProcessingHistory(
      id: id,
      originalImagePath: originalImagePath,
      processedImagePath: processedImagePath,
      type: switch (type) {
        ProcessingTypeModel.face => ProcessingType.face,
        ProcessingTypeModel.document => ProcessingType.document,
      },
      createdAt: createdAt,
      fileSizeBytes: fileSizeBytes,
      thumbnailPath: thumbnailPath,
      pdfPath: pdfPath,
      extractedText: extractedText,
      facesDetected: facesDetected,
      faceRects: faceRects
          .where((r) => r.length == 4)
          .map((r) => (left: r[0], top: r[1], width: r[2], height: r[3]))
          .toList(growable: false),
      faceContours: faceContours
          .map(
            (contour) => contour
                .where((p) => p.length == 2)
                .map((p) => (x: p[0], y: p[1]))
                .toList(growable: false),
          )
          .toList(growable: false),
    );
  }
}
