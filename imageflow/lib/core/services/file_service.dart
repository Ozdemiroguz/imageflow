import 'dart:io';

import 'package:get/get.dart';
import 'package:path_provider/path_provider.dart';

import '../constants/storage_constants.dart';

class FileService extends GetxService {
  late final String _basePath;

  String get basePath => _basePath;
  String get originalsPath => '$_basePath/${StorageConstants.originalsDir}';
  String get processedPath => '$_basePath/${StorageConstants.processedDir}';
  String get pdfsPath => '$_basePath/${StorageConstants.pdfsDir}';
  String get thumbnailsPath => '$_basePath/${StorageConstants.thumbnailsDir}';

  Future<FileService> init() async {
    final appDir = await getApplicationSupportDirectory();
    _basePath = appDir.path;

    await Future.wait([
      Directory(originalsPath).create(recursive: true),
      Directory(processedPath).create(recursive: true),
      Directory(pdfsPath).create(recursive: true),
      Directory(thumbnailsPath).create(recursive: true),
    ]);
    return this;
  }

  // Absolute paths — for file I/O during processing
  String originalFilePath(String uuid) => '$originalsPath/$uuid.jpg';
  String processedFilePath(String uuid) => '$processedPath/$uuid.jpg';
  String pdfFilePath(String uuid) => '$pdfsPath/$uuid.pdf';
  String thumbnailFilePath(String uuid) => '$thumbnailsPath/${uuid}_thumb.jpg';

  // Relative paths — for persistence (immune to container UUID changes)
  String relativeOriginalPath(String uuid) =>
      '${StorageConstants.originalsDir}/$uuid.jpg';
  String relativeProcessedPath(String uuid) =>
      '${StorageConstants.processedDir}/$uuid.jpg';
  String relativePdfPath(String uuid) =>
      '${StorageConstants.pdfsDir}/$uuid.pdf';
  String relativeThumbnailPath(String uuid) =>
      '${StorageConstants.thumbnailsDir}/${uuid}_thumb.jpg';

  /// Resolves a stored path to an absolute path.
  /// Handles both relative (new) and absolute (legacy) paths.
  String resolvePath(String storedPath) {
    if (storedPath.startsWith('/')) return storedPath; // legacy absolute path
    return '$_basePath/$storedPath';
  }

  Future<void> deleteFiles(String uuid) async {
    final files = [
      File(originalFilePath(uuid)),
      File(processedFilePath(uuid)),
      File(pdfFilePath(uuid)),
      File(thumbnailFilePath(uuid)),
    ];

    for (final file in files) {
      // ignore: avoid_slow_async_io
      if (await file.exists()) {
        // ignore: avoid_slow_async_io
        await file.delete();
      }
    }
  }
}
