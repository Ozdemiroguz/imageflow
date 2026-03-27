part of 'realtime_result_panels.dart';

class RealtimeResultPanelCard extends StatelessWidget {
  const RealtimeResultPanelCard({
    super.key,
    required this.title,
    required this.status,
    required this.icon,
    required this.bytes,
    required this.isExpanded,
    required this.onTap,
  });

  final String title;
  final String status;
  final IconData icon;
  final Uint8List? bytes;
  final bool isExpanded;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final scheme = context.colors;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(tokens.radiusMd),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: EdgeInsets.all(tokens.spacingSm),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.38),
            borderRadius: BorderRadius.circular(tokens.radiusMd),
            border: Border.all(
              color: isExpanded
                  ? tokens.realtimeDocumentStroke
                  : scheme.outlineVariant.withValues(alpha: 0.45),
              width: isExpanded ? 1.4 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, size: 16, color: scheme.onSurface),
                  SizedBox(width: tokens.spacingXs),
                  Expanded(
                    child: Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: scheme.onSurface,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  InkWell(
                    onTap: onTap,
                    borderRadius: BorderRadius.circular(tokens.radiusSm),
                    child: Padding(
                      padding: EdgeInsets.all(tokens.spacingXs),
                      child: Icon(
                        isExpanded
                            ? Icons.close_fullscreen_rounded
                            : Icons.open_in_full_rounded,
                        size: 16,
                        color: scheme.onSurface.withValues(alpha: 0.82),
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: tokens.spacingXs),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(tokens.radiusSm),
                  child: Container(
                    width: double.infinity,
                    color: Colors.black.withValues(alpha: 0.22),
                    child: bytes == null
                        ? Center(
                            child: Icon(
                              icon,
                              size: 22,
                              color: scheme.onSurface.withValues(alpha: 0.56),
                            ),
                          )
                        : Image.memory(
                            bytes!,
                            fit: BoxFit.contain,
                            gaplessPlayback: true,
                          ),
                  ),
                ),
              ),
              SizedBox(height: tokens.spacingXs),
              Text(
                status,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: scheme.onSurface.withValues(alpha: 0.78),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
