import 'package:get/get.dart';

import '../presentation/models/batch_item_state.dart';

class BatchItemStateMutator {
  const BatchItemStateMutator();

  void set(
    RxList<BatchItemState> items, {
    required int index,
    required BatchItemState next,
  }) {
    if (index < 0 || index >= items.length) return;
    final current = items[index];
    if (_isSame(current, next)) return;
    items[index] = next;
  }

  bool _isSame(BatchItemState a, BatchItemState b) {
    return a.index == b.index &&
        a.imagePath == b.imagePath &&
        a.status == b.status &&
        a.step == b.step &&
        a.errorMessage == b.errorMessage &&
        a.errorCode == b.errorCode &&
        a.errorDetails == b.errorDetails &&
        identical(a.result, b.result);
  }
}
