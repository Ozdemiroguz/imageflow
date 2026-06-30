import 'dart:async';

import 'package:flutter/scheduler.dart';

import '../error/failure_ui_mapper.dart';
import '../error/failures.dart';
import '../error/result.dart';
import '../models/snack_data.dart';
import '../services/modal_service.dart';
import '../services/pdf_external_open_service.dart';

/// Presentation-level orchestrator for document-specific UI actions.
class DocumentActionsPresenter {
  DocumentActionsPresenter({
    required ModalService modal,
    required PdfExternalOpenService pdfExternalOpen,
  }) : _modal = modal,
       _pdfExternalOpen = pdfExternalOpen;

  final ModalService _modal;
  final PdfExternalOpenService _pdfExternalOpen;
  Future<void>? _activeOpen;

  Future<void> openPdfExternally(String? pdfPath) async {
    final inFlight = _activeOpen;
    if (inFlight != null) {
      await inFlight;
      return;
    }

    final completer = Completer<void>();
    _activeOpen = completer.future;
    _modal.showLoadingOverlay(message: 'Opening PDF...', showSpinner: false);
    try {
      await SchedulerBinding.instance.endOfFrame;
      final outcome = await _pdfExternalOpen.open(pdfPath ?? '');
      switch (outcome) {
        case Ok():
          return;
        case Error(:final failure):
          _showFailure(failure);
      }
    } finally {
      _modal.hideLoadingOverlay();
      if (!completer.isCompleted) {
        completer.complete();
      }
      if (identical(_activeOpen, completer.future)) {
        _activeOpen = null;
      }
    }
  }

  void showExtractedTextSheet(String? text) {
    final normalizedText = text?.trim();
    if (normalizedText == null || normalizedText.isEmpty) return;
    _modal.showExtractedTextSheet(text: normalizedText);
  }

  void _showFailure(Failure failure) {
    final ui = FailureUiMapper.map(failure);
    _modal.showSnack(
      SnackData(title: ui.title, message: ui.message, type: ui.type),
    );
  }
}
