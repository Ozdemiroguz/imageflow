import 'package:flutter/widgets.dart';

abstract interface class ModalContentBuilder {
  Widget buildLoadingOverlay({
    required String message,
    String? label,
    bool showSpinner = true,
  });

  Widget buildConfirmDialog({
    required String title,
    required String message,
    required String confirmLabel,
    required String cancelLabel,
    required bool isDestructive,
  });

  Widget buildErrorDetailsSheet({
    required String title,
    required String code,
    required String message,
    String? details,
    String? imagePath,
  });

  Widget buildExtractedTextSheet({required String text, required String title});
}
