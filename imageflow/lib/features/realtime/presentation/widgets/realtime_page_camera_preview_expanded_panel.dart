part of 'realtime_page_camera_preview.dart';

class _RealtimeExpandedLivePanel extends StatelessWidget {
  const _RealtimeExpandedLivePanel({
    required this.controller,
    required this.isFace,
  });

  final RealtimeCameraController controller;
  final bool isFace;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final tokens = context.tokens;
    final title = isFace ? 'Face (Live)' : 'Document (Live)';
    final icon = isFace
        ? Icons.face_retouching_natural_outlined
        : Icons.description_outlined;

    return Align(
      alignment: Alignment.topRight,
      child: Padding(
        padding: EdgeInsets.all(tokens.spacingMd),
        child: FractionallySizedBox(
          widthFactor: 0.5,
          heightFactor: 0.5,
          alignment: Alignment.topRight,
          child: Container(
            padding: EdgeInsets.all(tokens.spacingSm),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.68),
              borderRadius: BorderRadius.circular(tokens.radiusMd),
              border: Border.all(
                color: tokens.realtimeDocumentStroke.withValues(alpha: 0.95),
                width: 1.4,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: tokens.spacingXs,
              children: [
                Row(
                  spacing: tokens.spacingXs,
                  children: [
                    Icon(icon, size: 16, color: colors.onSurface),
                    Expanded(
                      child: Text(
                        title,
                        style: Theme.of(context).textTheme.labelMedium
                            ?.copyWith(
                              color: colors.onSurface,
                              fontWeight: FontWeight.w600,
                            ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    InkWell(
                      onTap: controller.clearExpandedPreviewTarget,
                      borderRadius: BorderRadius.circular(tokens.radiusSm),
                      child: Padding(
                        padding: EdgeInsets.all(tokens.spacingXs),
                        child: Icon(
                          Icons.close,
                          size: 16,
                          color: colors.onSurface.withValues(alpha: 0.86),
                        ),
                      ),
                    ),
                  ],
                ),
                Expanded(
                  child: _RealtimeExpandedLivePanelPreview(
                    controller: controller,
                    isFace: isFace,
                    icon: icon,
                  ),
                ),
                _RealtimeExpandedLivePanelStatus(
                  controller: controller,
                  isFace: isFace,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RealtimeExpandedLivePanelPreview extends StatelessWidget {
  const _RealtimeExpandedLivePanelPreview({
    required this.controller,
    required this.isFace,
    required this.icon,
  });

  final RealtimeCameraController controller;
  final bool isFace;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final tokens = context.tokens;

    return Obx(() {
      final previewBytes = isFace
          ? controller.facePreviewBytes.value
          : controller.documentPreviewBytes.value;
      return Container(
        width: double.infinity,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(tokens.radiusSm),
          border: Border.all(
            color: colors.outlineVariant.withValues(alpha: 0.35),
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: previewBytes == null
            ? Center(
                child: Icon(
                  icon,
                  size: 24,
                  color: colors.onSurface.withValues(alpha: 0.52),
                ),
              )
            : Image.memory(
                previewBytes,
                fit: BoxFit.contain,
                gaplessPlayback: true,
                cacheWidth: 400,
              ),
      );
    });
  }
}

class _RealtimeExpandedLivePanelStatus extends StatelessWidget {
  const _RealtimeExpandedLivePanelStatus({
    required this.controller,
    required this.isFace,
  });

  final RealtimeCameraController controller;
  final bool isFace;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Obx(() {
      final status = isFace
          ? controller.faceStatus.value
          : controller.documentStatus.value;
      return Text(
        status,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: colors.onSurface.withValues(alpha: 0.78),
        ),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      );
    });
  }
}
