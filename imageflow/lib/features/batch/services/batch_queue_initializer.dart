import 'dart:collection';

import '../../../core/error/failures.dart';
import '../../../core/error/result.dart';
import '../presentation/models/batch_item_state.dart';
import '../presentation/models/batch_item_status.dart';

class BatchQueueInitializer {
  const BatchQueueInitializer();

  Result<List<BatchItemState>> build(Object? args) {
    if (args is! List) {
      return Result.error(
        const RouteArgumentFailure(
          'Expected a list of image paths for batch processing.',
        ),
      );
    }

    final uniquePaths = LinkedHashSet<String>.from(
      args
          .whereType<String>()
          .map((path) => path.trim())
          .where((path) => path.isNotEmpty),
    ).toList(growable: false);

    if (uniquePaths.isEmpty) {
      return Result.error(const RouteArgumentFailure('No images selected.'));
    }

    final items = List<BatchItemState>.generate(
      uniquePaths.length,
      (index) => BatchItemState(
        index: index,
        imagePath: uniquePaths[index],
        status: BatchItemStatus.pending,
      ),
    );
    return Result.ok(items);
  }
}
