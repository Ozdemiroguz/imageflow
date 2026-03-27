import 'dart:async';

import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../error/failures.dart';
import '../error/result.dart';
import '../utils/log.dart';

class PdfExternalOpenService extends GetxService {
  static const _channel = MethodChannel('com.oguzhan.imageflow/pdf_external');
  static const _openTimeout = Duration(seconds: 10);

  Future<Result<void>> open(String pdfPath) => Result.guard(
    () async {
      final normalizedPath = pdfPath.trim();
      if (normalizedPath.isEmpty) {
        throw const PdfFailure('No PDF available to open.');
      }

      final opened = await _channel.invokeMethod<bool>(
        'openPdf',
        <String, dynamic>{'path': normalizedPath},
      ).timeout(_openTimeout);

      if (opened != true) {
        throw const PdfFailure('Could not open PDF externally.');
      }
    },
    onError: _mapFailure,
    onLog: (e, st) => Log.error(
      'External PDF open failed',
      error: e,
      stackTrace: st,
      tag: 'PdfExternalOpen',
    ),
  );

  Failure _mapFailure(Object error) {
    if (error is Failure) return error;

    if (error is PlatformException) {
      return switch (error.code) {
        'INVALID_ARGS' ||
        'INVALID_PATH' => const PdfFailure('Invalid PDF file path.'),
        'FILE_NOT_FOUND' => const FileFailure('PDF file could not be found.'),
        'PDF_APP_NOT_FOUND' => const PdfFailure(
          'No external PDF viewer found on device.',
        ),
        'OPEN_FAILED' => const PdfFailure('Could not open PDF externally.'),
        _ => NativeChannelFailure(
          'External PDF open failed: ${error.message ?? error.code}',
        ),
      };
    }
    if (error is TimeoutException) {
      return const PdfFailure('Opening PDF timed out. Please try again.');
    }

    return const NativeChannelFailure('Failed to open PDF externally.');
  }
}
