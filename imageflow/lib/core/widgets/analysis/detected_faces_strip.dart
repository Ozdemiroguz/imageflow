import 'dart:isolate';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:get/get.dart';

import '../../services/face_thumbnail_cache_service.dart';
import '../../theme/app_tokens.dart';
import '../../theme/context_theme_extensions.dart';
import '../../utils/face_thumbnail_builder.dart';
import '../../utils/log.dart';
import '../design_system/app_shimmer.dart';
import 'face_preview_items_view.dart';

part 'detected_faces_strip_loading_shimmer.dart';
part 'detected_faces_strip_state.dart';
part 'detected_faces_strip_thumbnail_utils.dart';

class DetectedFacesStrip extends StatefulWidget {
  const DetectedFacesStrip({
    super.key,
    required this.imagePath,
    required this.faceRects,
    this.faceContours = const [],
    this.fallbackImagePath,
    this.title = 'Detected faces',
    this.maxItems = 8,
  });

  final String imagePath;
  final List<({int left, int top, int width, int height})> faceRects;
  final List<List<({int x, int y})>> faceContours;
  final String? fallbackImagePath;
  final String title;
  final int maxItems;

  @override
  State<DetectedFacesStrip> createState() => _DetectedFacesStripState();
}
