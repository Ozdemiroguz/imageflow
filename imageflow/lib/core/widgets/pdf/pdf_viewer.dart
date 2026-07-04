import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../constants/app_constants.dart';
import '../../error/failure_ui_mapper.dart';
import '../../theme/app_tokens.dart';
import '../../theme/context_theme_extensions.dart';
import '../design_system/app_shimmer.dart';
import '../design_system/app_shimmer_style.dart';
import 'pdf_load_error.dart';
import 'pdf_viewer_controller.dart';

part 'pdf_viewer_state.dart';

class PdfViewer extends StatefulWidget {
  const PdfViewer({
    super.key,
    required this.controller,
    this.initialLoadDelay = AppConstants.routeTransitionSettleDelay,
  });

  final PdfViewerController controller;

  /// How long to wait before kicking off the first rasterization. Defaults to
  /// the route-transition settle delay so the native PDF raster (and its
  /// multi-MB channel transfer) doesn't compete with the entrance animation;
  /// the shimmer skeleton covers the wait. Pass [Duration.zero] in tests.
  final Duration initialLoadDelay;

  @override
  State<PdfViewer> createState() => _PdfViewerState();
}
