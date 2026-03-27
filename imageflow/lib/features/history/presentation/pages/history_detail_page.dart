import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../core/theme/app_tokens.dart';
import '../../../../core/widgets/design_system/app_primary_button.dart';
import '../../../../core/widgets/analysis/detected_faces_strip.dart';
import '../../../../core/widgets/analysis/document_info_strip.dart';
import '../../../../core/widgets/analysis/face_compact_previews_row.dart';
import '../../../../core/widgets/analysis/face_swipe_comparison.dart';
import '../../../../core/widgets/analysis/result_metadata_panel.dart';
import '../../../../core/widgets/pdf/document_preview_panel.dart';
import '../controllers/history_detail_controller.dart';

part 'history_detail_page_face_layout.dart';
part 'history_detail_page_document_layout.dart';

class HistoryDetailPage extends GetView<HistoryDetailController> {
  const HistoryDetailPage({super.key});

  @override
  Widget build(BuildContext context) {
    return controller.isDocument
        ? _HistoryDocumentDetailLayout(controller: controller)
        : _HistoryFaceDetailLayout(controller: controller);
  }
}
