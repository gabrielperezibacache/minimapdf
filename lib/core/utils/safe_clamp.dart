/// Clamp seguro: no lanza si `min > max` ni con valores no finitos.
double safeClamp(double value, double min, double max) {
  var lo = min;
  var hi = max;
  if (lo.isFinite && hi.isFinite && lo > hi) {
    final tmp = lo;
    lo = hi;
    hi = tmp;
  }

  if (value.isNaN) {
    if (lo.isFinite) return lo;
    if (hi.isFinite) return hi;
    return 0;
  }
  if (value == double.infinity) {
    if (hi.isFinite) return hi;
    if (lo.isFinite) return lo;
    return value;
  }
  if (value == double.negativeInfinity) {
    if (lo.isFinite) return lo;
    if (hi.isFinite) return hi;
    return value;
  }

  if (!lo.isFinite && !hi.isFinite) return value;
  if (!lo.isFinite) return value > hi ? hi : value;
  if (!hi.isFinite) return value < lo ? lo : value;
  return value.clamp(lo, hi).toDouble();
}
