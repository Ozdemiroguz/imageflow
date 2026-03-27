import 'dart:developer' as dev;

import 'package:flutter/foundation.dart';

abstract final class Log {
  static void debug(String message, {String? tag}) {
    if (!kDebugMode) return;
    dev.log(message, name: tag ?? 'DEBUG');
  }

  static void info(String message, {String? tag}) {
    if (!kDebugMode) return;
    dev.log(message, name: tag ?? 'INFO');
  }

  static void warning(String message, {String? tag}) {
    if (!kDebugMode) return;
    dev.log('⚠️ $message', name: tag ?? 'WARN');
  }

  static void error(String message, {Object? error, StackTrace? stackTrace, String? tag}) {
    if (!kDebugMode) return;
    dev.log(
      message,
      name: tag ?? 'ERROR',
      error: error,
      stackTrace: stackTrace,
    );
  }
}
