part of 'processing_history_model.dart';

@HiveType(typeId: 1)
enum ProcessingTypeModel {
  @HiveField(0)
  face,
  @HiveField(1)
  document,
}
