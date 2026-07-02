import 'package:flutter_test/flutter_test.dart';
import 'package:imageflow/core/error/failures.dart';
import 'package:imageflow/core/error/result.dart';
import 'package:imageflow/features/batch/presentation/models/batch_item_status.dart';
import 'package:imageflow/features/batch/presentation/services/batch_queue_initializer.dart';

void main() {
  group('buildBatchQueue', () {
    test('non-list args → RouteArgumentFailure', () {
      final result = buildBatchQueue('not a list');
      expect(result.isError, isTrue);
      expect((result as Error).failure, isA<RouteArgumentFailure>());
    });

    test('builds a pending queue preserving order', () {
      final result = buildBatchQueue(['a.jpg', 'b.jpg', 'c.jpg']);

      expect(result.isOk, isTrue);
      final items = (result as Ok).value;
      expect(items.map((i) => i.imagePath), ['a.jpg', 'b.jpg', 'c.jpg']);
      expect(items.map((i) => i.index), [0, 1, 2]);
      expect(items.map((i) => i.status), everyElement(BatchItemStatus.pending));
    });

    test('de-duplicates paths, keeping first occurrence order', () {
      final result = buildBatchQueue(['a.jpg', 'b.jpg', 'a.jpg']);
      final items = (result as Ok).value;
      expect(items.map((i) => i.imagePath), ['a.jpg', 'b.jpg']);
    });

    test('trims whitespace and drops blank/whitespace-only paths', () {
      final result = buildBatchQueue(['  a.jpg  ', '   ', '', 'b.jpg']);
      final items = (result as Ok).value;
      expect(items.map((i) => i.imagePath), ['a.jpg', 'b.jpg']);
    });

    test('ignores non-string entries', () {
      final result = buildBatchQueue(['a.jpg', 42, null, 'b.jpg']);
      final items = (result as Ok).value;
      expect(items.map((i) => i.imagePath), ['a.jpg', 'b.jpg']);
    });

    test('empty (or all-blank) list → RouteArgumentFailure', () {
      expect(buildBatchQueue(<String>[]).isError, isTrue);
      expect(buildBatchQueue(['  ', '']).isError, isTrue);
    });
  });
}
