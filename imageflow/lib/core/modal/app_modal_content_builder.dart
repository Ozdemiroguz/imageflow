import 'package:flutter/widgets.dart';

import 'modal_content_builder.dart';
import '../widgets/modal/confirm_dialog.dart';
import '../widgets/modal/error_details_sheet.dart';
import '../widgets/modal/extracted_text_sheet.dart';
import '../widgets/modal/loading_overlay.dart';

class AppModalContentBuilder implements ModalContentBuilder {
  const AppModalContentBuilder();

  @override
  Widget buildLoadingOverlay({
    required String message,
    String? label,
    bool showSpinner = true,
  }) {
    return LoadingOverlay(message: message, label: label, showSpinner: showSpinner);
  }

  @override
  Widget buildConfirmDialog({
    required String title,
    required String message,
    required String confirmLabel,
    required String cancelLabel,
    required bool isDestructive,
  }) {
    return ConfirmDialog(
      title: title,
      message: message,
      confirmLabel: confirmLabel,
      cancelLabel: cancelLabel,
      isDestructive: isDestructive,
    );
  }

  @override
  Widget buildErrorDetailsSheet({
    required String title,
    required String code,
    required String message,
    String? details,
    String? imagePath,
  }) {
    return ErrorDetailsSheet(
      title: title,
      code: code,
      message: message,
      details: details,
      imagePath: imagePath,
    );
  }

  @override
  Widget buildExtractedTextSheet({
    required String text,
    required String title,
  }) {
    return ExtractedTextSheet(text: text, title: title);
  }
}
