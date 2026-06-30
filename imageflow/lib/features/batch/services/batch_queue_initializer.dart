import 'dart:collection';

import '../../../core/error/failures.dart';
import '../../../core/error/result.dart';
import '../presentation/models/batch_item_state.dart';
import '../presentation/models/batch_item_status.dart';

/// Validates the batch route arguments (a list of image paths) and builds the
/// initial, de-duplicated queue of pending [BatchItemState]s.
///
/// A pure function — it has no dependencies and no state, so it is a top-level
/// function rather than a class.
Result<List<BatchItemState>> buildBatchQueue(Object? args) {
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

  return Result.ok(
    List<BatchItemState>.generate(
      uniquePaths.length,
      (index) => BatchItemState(
        index: index,
        imagePath: uniquePaths[index],
        status: BatchItemStatus.pending,
      ),
    ),
  );
}
