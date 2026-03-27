import 'dart:collection';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../modal/modal_content_builder.dart';
import '../models/snack_data.dart';
import '../theme/app_tokens.dart';
import '../utils/log.dart';

/// Centralized UI modal service (dialog, bottom sheet, snackbar).
class ModalService extends GetxService {
  ModalService({required ModalContentBuilder contentBuilder})
    : _contentBuilder = contentBuilder;

  static const _tag = 'ModalService';
  static const _defaultLoadingMessage = 'Loading...';

  final ModalContentBuilder _contentBuilder;
  final Queue<SnackData> _snackQueue = Queue<SnackData>();
  var _isSnackShowing = false;
  OverlayEntry? _loadingOverlayEntry;
  var _loadingOverlayRefCount = 0;

  Future<T?> showDialogWidget<T>(
    Widget dialog, {
    bool barrierDismissible = true,
  }) {
    return Get.dialog<T>(dialog, barrierDismissible: barrierDismissible);
  }

  void showLoadingOverlay({
    String message = _defaultLoadingMessage,
    String? label,
    bool showSpinner = true,
  }) {
    _loadingOverlayRefCount += 1;
    if (_loadingOverlayEntry != null) return;

    final overlay = _resolveRootOverlay();
    if (overlay == null) {
      _loadingOverlayRefCount = 0;
      Log.warning('Loading overlay skipped: no root overlay.', tag: _tag);
      return;
    }

    _loadingOverlayEntry = OverlayEntry(
      builder: (_) => _contentBuilder.buildLoadingOverlay(
        message: message,
        label: label,
        showSpinner: showSpinner,
      ),
    );
    overlay.insert(_loadingOverlayEntry!);
  }

  void hideLoadingOverlay() {
    if (_loadingOverlayRefCount > 0) {
      _loadingOverlayRefCount -= 1;
    }
    if (_loadingOverlayRefCount > 0) return;
    _removeLoadingOverlay();
  }

  void hideAllLoadingOverlays() {
    _loadingOverlayRefCount = 0;
    _removeLoadingOverlay();
  }

  Future<T?> showBottomSheet<T>({
    required WidgetBuilder builder,
    bool isScrollControlled = false,
    bool useSafeArea = true,
    bool showDragHandle = false,
  }) {
    final context = Get.context;
    if (context == null) return Future<T?>.value(null);

    return showModalBottomSheet<T>(
      context: context,
      isScrollControlled: isScrollControlled,
      useSafeArea: useSafeArea,
      showDragHandle: showDragHandle,
      builder: builder,
    );
  }

  Future<bool> confirm({
    required String title,
    required String message,
    String confirmLabel = 'Delete',
    String cancelLabel = 'Cancel',
    bool isDestructive = true,
  }) async {
    final result = await showDialogWidget<bool>(
      _contentBuilder.buildConfirmDialog(
        title: title,
        message: message,
        confirmLabel: confirmLabel,
        cancelLabel: cancelLabel,
        isDestructive: isDestructive,
      ),
    );
    return result ?? false;
  }

  Future<void> showErrorDetailsSheet({
    String title = 'Error Details',
    String? code,
    String fallbackCode = 'UNKNOWN',
    String? message,
    String fallbackMessage = 'Something went wrong.',
    String? details,
    String? imagePath,
  }) {
    final normalizedCode = _normalizedOrFallback(code, fallbackCode);
    final normalizedMessage = _normalizedOrFallback(message, fallbackMessage);
    final normalizedDetails = _normalized(details);
    final normalizedImagePath = _normalized(imagePath);

    return showBottomSheet<void>(
      useSafeArea: true,
      isScrollControlled: true,
      builder: (_) => _contentBuilder.buildErrorDetailsSheet(
        title: title,
        code: normalizedCode,
        message: normalizedMessage,
        details: normalizedDetails,
        imagePath: normalizedImagePath,
      ),
    );
  }

  Future<void> showExtractedTextSheet({
    required String text,
    String title = 'Document Content',
  }) {
    final normalizedText = _normalized(text);
    if (normalizedText == null) return Future<void>.value();

    return showBottomSheet<void>(
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _contentBuilder.buildExtractedTextSheet(
        text: normalizedText,
        title: title,
      ),
    );
  }

  void showSnack(SnackData data) {
    _snackQueue.addLast(data);
    _showNextSnackIfIdle();
  }

  void _showNextSnackIfIdle() {
    if (_isSnackShowing || _snackQueue.isEmpty) return;

    final context = Get.context;
    if (context == null) {
      Log.warning('Snackbar skipped: no active context.', tag: _tag);
      _snackQueue.clear();
      return;
    }

    final next = _snackQueue.removeFirst();
    final tokens = context.tokens;
    final background = next.type.resolveBackground(context);
    final foreground = next.type.resolveForeground(context);

    _isSnackShowing = true;
    try {
      Get.snackbar(
        next.title,
        next.message,
        snackPosition: SnackPosition.BOTTOM,
        duration: next.duration,
        backgroundColor: background,
        colorText: foreground,
        margin: EdgeInsets.all(tokens.spacingLg),
        borderRadius: tokens.radiusMd,
        icon: Icon(next.type.icon, color: foreground),
        snackbarStatus: (status) {
          if (status == SnackbarStatus.CLOSED) {
            _isSnackShowing = false;
            _showNextSnackIfIdle();
          }
        },
      );
    } catch (e, st) {
      _isSnackShowing = false;
      Log.error('Failed to show snackbar', error: e, stackTrace: st, tag: _tag);
      _showNextSnackIfIdle();
    }
  }

  String _normalizedOrFallback(String? value, String fallback) {
    final normalized = _normalized(value);
    return normalized ?? fallback;
  }

  String? _normalized(String? value) {
    if (value == null) return null;
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  void _removeLoadingOverlay() {
    _loadingOverlayEntry?.remove();
    _loadingOverlayEntry = null;
  }

  OverlayState? _resolveRootOverlay() {
    final direct = Get.key.currentState?.overlay;
    if (direct != null) return direct;

    OverlayState? fromContext(BuildContext? context) {
      if (context == null) return null;
      final navigator = Navigator.maybeOf(context, rootNavigator: true);
      if (navigator?.overlay != null) {
        return navigator!.overlay;
      }
      return Overlay.maybeOf(context, rootOverlay: true);
    }

    return fromContext(Get.key.currentContext) ??
        fromContext(Get.overlayContext) ??
        fromContext(Get.context);
  }
}
