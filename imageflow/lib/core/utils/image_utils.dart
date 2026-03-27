import 'dart:io';
import 'dart:isolate';

import 'package:image/image.dart' as img;

abstract class ImageUtils {
  static const _defaultJpegQuality = 92;

  /// Bakes EXIF orientation into pixel data so the file is physically upright.
  ///
  /// iOS front camera selfies embed a mirrored EXIF orientation tag
  /// (e.g. leftMirrored) that ML Kit's face detector cannot handle,
  /// resulting in 0 faces detected. This physically rotates/flips the pixels
  /// to match the EXIF tag, then saves with orientation = up.
  static Future<void> normalizeOrientation(
    String imagePath, {
    int quality = _defaultJpegQuality,
  }) async {
    await Isolate.run(() {
      final file = File(imagePath);
      final bytes = file.readAsBytesSync();
      final image = img.decodeImage(bytes);
      if (image == null) return;

      final oriented = img.bakeOrientation(image);
      if (identical(oriented, image)) return;

      // Clear EXIF so subsequent decodeImage won't re-apply orientation.
      oriented.exif = img.ExifData();

      file.writeAsBytesSync(img.encodeJpg(oriented, quality: quality));
    });
  }

  static Future<void> rotateInPlace(
    String imagePath, {
    required int degrees,
    int quality = _defaultJpegQuality,
  }) async {
    final normalized = ((degrees % 360) + 360) % 360;
    if (normalized == 0) return;
    await Isolate.run(() {
      final file = File(imagePath);
      final bytes = file.readAsBytesSync();
      final image = img.decodeImage(bytes);
      if (image == null) return;
      final rotated = img.copyRotate(image, angle: normalized);
      rotated.exif = img.ExifData();
      file.writeAsBytesSync(img.encodeJpg(rotated, quality: quality));
    });
  }

  static Future<void> flipHorizontalInPlace(
    String imagePath, {
    int quality = _defaultJpegQuality,
  }) async {
    await Isolate.run(() {
      final file = File(imagePath);
      final bytes = file.readAsBytesSync();
      final decoded = img.decodeImage(bytes);
      if (decoded == null) return;

      final flipped = img.flipHorizontal(decoded);
      flipped.exif = img.ExifData();
      file.writeAsBytesSync(img.encodeJpg(flipped, quality: quality));
    });
  }

  static Future<bool> hasMirroredExifOrientation(String imagePath) async {
    final orientation = await Isolate.run(() {
      final bytes = File(imagePath).readAsBytesSync();
      final decoded = img.decodeImage(bytes);
      if (decoded == null) return 1;
      if (!decoded.exif.imageIfd.hasOrientation) return 1;
      return decoded.exif.imageIfd.orientation ?? 1;
    });
    // EXIF orientations with mirrored variants:
    // 2 (up mirrored), 4 (down mirrored), 5 (left mirrored), 7 (right mirrored)
    return orientation == 2 ||
        orientation == 4 ||
        orientation == 5 ||
        orientation == 7;
  }

  /// Runs [run] with a temporary downscaled JPEG path for ML routing.
  ///
  /// If [maxDimension] is null/invalid or the source is already within bounds,
  /// [run] receives [sourcePath] directly.
  static Future<T> withPreparedMlInputPath<T>({
    required String sourcePath,
    required Future<T> Function(String inputPath) run,
    int? maxDimension,
    int quality = 86,
  }) async {
    if (maxDimension == null || maxDimension <= 0) {
      return run(sourcePath);
    }

    final prepared = await Isolate.run(() {
      final sourceFile = File(sourcePath);
      final bytes = sourceFile.readAsBytesSync();
      final decoded = img.decodeImage(bytes);
      if (decoded == null) {
        return (path: sourcePath, temporary: false);
      }

      final longest = decoded.width > decoded.height
          ? decoded.width
          : decoded.height;
      if (longest <= maxDimension) {
        return (path: sourcePath, temporary: false);
      }

      final scale = maxDimension / longest;
      final targetWidth = (decoded.width * scale).round().clamp(
        1,
        decoded.width,
      );
      final targetHeight = (decoded.height * scale).round().clamp(
        1,
        decoded.height,
      );
      final resized = img.copyResize(
        decoded,
        width: targetWidth,
        height: targetHeight,
        interpolation: img.Interpolation.linear,
      );
      resized.exif = img.ExifData();

      final fileName = sourceFile.uri.pathSegments.isEmpty
          ? 'image.jpg'
          : sourceFile.uri.pathSegments.last;
      final tempPath =
          '${sourceFile.parent.path}${Platform.pathSeparator}.ml_$fileName.$maxDimension.$quality.jpg';
      File(tempPath).writeAsBytesSync(img.encodeJpg(resized, quality: quality));
      return (path: tempPath, temporary: true);
    });

    try {
      return await run(prepared.path);
    } finally {
      if (prepared.temporary) {
        try {
          await File(prepared.path).delete();
        } catch (_) {
          // Best-effort cleanup.
        }
      }
    }
  }

  static Future<void> generateThumbnail({
    required String sourcePath,
    required String targetPath,
    int width = 200,
  }) async {
    await Isolate.run(() {
      final bytes = File(sourcePath).readAsBytesSync();
      final image = img.decodeImage(bytes);
      if (image == null) return;

      final thumbnail = img.copyResize(image, width: width);
      final encoded = img.encodeJpg(thumbnail, quality: 80);
      File(targetPath).writeAsBytesSync(encoded);
    });
  }
}
