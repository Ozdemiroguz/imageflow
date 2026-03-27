import 'package:flutter/material.dart';

import '../../../../core/enums/processing_type.dart';
import '../../../../core/widgets/design_system/app_icon_info_card.dart';

class DetectionSummaryCard extends StatelessWidget {
  const DetectionSummaryCard({
    super.key,
    required this.type,
    required this.facesDetected,
    required this.extractedTextLength,
  });

  final ProcessingType type;
  final int facesDetected;
  final int extractedTextLength;

  @override
  Widget build(BuildContext context) {
    final (icon, label) = switch (type) {
      ProcessingType.face => (
          Icons.face_outlined,
          facesDetected > 0
              ? '$facesDetected ${facesDetected == 1 ? 'face' : 'faces'} detected'
              : 'Face detection applied',
        ),
      ProcessingType.document => (
          Icons.text_snippet_outlined,
          '$extractedTextLength characters extracted',
        ),
    };

    return AppIconInfoCard(
      icon: icon,
      title: label,
    );
  }
}
