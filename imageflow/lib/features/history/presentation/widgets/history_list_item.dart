import 'package:flutter/material.dart';

import '../../../../core/enums/processing_type.dart';
import '../../../../core/theme/app_tokens.dart';
import '../../../../core/theme/context_theme_extensions.dart';
import '../../domain/entities/processing_history.dart';
import 'history_thumbnail.dart';

class HistoryListItem extends StatelessWidget {
  const HistoryListItem({
    super.key,
    required this.history,
    required this.onConfirmDelete,
    required this.onDismissed,
    required this.onOpenDetail,
  });

  final ProcessingHistory history;
  final Future<bool> Function() onConfirmDelete;
  final VoidCallback onDismissed;
  final VoidCallback onOpenDetail;
  static const _dismissMovementDuration = Duration(milliseconds: 280);
  static const _dismissResizeDuration = Duration(milliseconds: 240);

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;

    final radius = BorderRadius.circular(tokens.radiusMd);

    return Dismissible(
      key: ValueKey(history.id),
      direction: DismissDirection.endToStart,
      movementDuration: _dismissMovementDuration,
      resizeDuration: _dismissResizeDuration,
      dismissThresholds: const {DismissDirection.endToStart: 0.28},
      background: Padding(
        padding: EdgeInsets.symmetric(vertical: tokens.spacingXs),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: context.colors.error,
            borderRadius: radius,
          ),
          child: Align(
            alignment: .centerRight,
            child: Padding(
              padding: EdgeInsets.only(right: tokens.spacingLg),
              child: Icon(
                Icons.delete_outline,
                color: context.colors.onError,
              ),
            ),
          ),
        ),
      ),
      confirmDismiss: (_) => onConfirmDelete(),
      onDismissed: (_) => onDismissed(),
      child: Card(
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(borderRadius: radius),
        margin: EdgeInsets.symmetric(vertical: tokens.spacingXs),
        child: ListTile(
          leading: HistoryThumbnail(path: history.thumbnailPath),
          title: Text(
            history.type == ProcessingType.face
                ? 'Face Detection'
                : 'Document Scan',
            style: context.text.titleMedium,
          ),
          subtitle: Text(
            _formatDate(history.createdAt),
            style: context.text.labelSmall?.copyWith(
              color: context.colors.onSurface.withValues(alpha: 0.5),
            ),
          ),
          trailing: const Icon(Icons.chevron_right),
          onTap: onOpenDetail,
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}
