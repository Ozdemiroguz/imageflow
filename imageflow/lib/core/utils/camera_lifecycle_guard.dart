class CameraLifecycleGuard {
  var _isBusy = false;
  var _generation = 0;

  bool get isBusy => _isBusy;

  bool begin() {
    if (_isBusy) return false;
    _isBusy = true;
    return true;
  }

  void end() {
    _isBusy = false;
  }

  int nextGeneration({required bool enabled}) {
    if (!enabled) return _generation;
    _generation += 1;
    return _generation;
  }

  void invalidate({required bool enabled}) {
    if (!enabled) return;
    _generation += 1;
  }

  bool isCurrent(int generation, {required bool enabled}) {
    if (!enabled) return true;
    return _generation == generation;
  }
}
