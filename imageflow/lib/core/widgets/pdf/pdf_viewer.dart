import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../error/failure_ui_mapper.dart';
import '../../theme/app_tokens.dart';
import '../../theme/context_theme_extensions.dart';
import '../design_system/app_shimmer.dart';
import '../design_system/app_shimmer_style.dart';
import 'pdf_load_error.dart';
import 'pdf_viewer_controller.dart';

part 'pdf_viewer_state.dart';

class PdfViewer extends StatefulWidget {
  const PdfViewer({super.key, required this.controller});

  final PdfViewerController controller;

  @override
  State<PdfViewer> createState() => _PdfViewerState();
}
