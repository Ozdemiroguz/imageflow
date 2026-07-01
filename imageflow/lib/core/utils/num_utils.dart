/// Type-preserving clamp helpers.
///
/// Dart's `num.clamp` returns `num`, forcing a cast back to `int`/`double` at
/// every call site. These keep the type and avoid that noise. Top-level so they
/// can be used inside `Isolate.run` closures (which cannot capture instance
/// methods).
int clampInt(int value, int min, int max) {
  return value < min ? min : (value > max ? max : value);
}

double clampDouble(double value, double min, double max) {
  return value < min ? min : (value > max ? max : value);
}
