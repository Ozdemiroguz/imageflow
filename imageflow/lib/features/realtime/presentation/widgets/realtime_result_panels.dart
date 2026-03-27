import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../../../core/theme/app_tokens.dart';
import '../../../../core/theme/context_theme_extensions.dart';

part 'realtime_result_panels_panel.dart';

class RealtimeResultPanels extends StatelessWidget {
  const RealtimeResultPanels({
    super.key,
    required this.facePreviewBytes,
    required this.faceStatus,
    required this.documentPreviewBytes,
    required this.documentStatus,
    required this.onFaceTap,
    required this.onDocumentTap,
    required this.isFaceExpanded,
    required this.isDocumentExpanded,
  });

  final Uint8List? facePreviewBytes;
  final String faceStatus;
  final Uint8List? documentPreviewBytes;
  final String documentStatus;
  final VoidCallback onFaceTap;
  final VoidCallback onDocumentTap;
  final bool isFaceExpanded;
  final bool isDocumentExpanded;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;

    return Row(
      children: [
        Expanded(
          child: RealtimeResultPanelCard(
            title: 'Face',
            status: faceStatus,
            icon: Icons.face_retouching_natural_outlined,
            bytes: facePreviewBytes,
            isExpanded: isFaceExpanded,
            onTap: onFaceTap,
          ),
        ),
        SizedBox(width: tokens.spacingSm),
        Expanded(
          child: RealtimeResultPanelCard(
            title: 'Document',
            status: documentStatus,
            icon: Icons.description_outlined,
            bytes: documentPreviewBytes,
            isExpanded: isDocumentExpanded,
            onTap: onDocumentTap,
          ),
        ),
      ],
    );
  }
}
