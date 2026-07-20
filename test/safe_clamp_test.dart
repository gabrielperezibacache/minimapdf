import 'package:flutter_test/flutter_test.dart';
import 'package:minimal_pdf/core/utils/safe_clamp.dart';

void main() {
  group('safeClamp', () {
    test('clampa en rango normal', () {
      expect(safeClamp(5, 0, 10), 5);
      expect(safeClamp(-1, 0, 10), 0);
      expect(safeClamp(99, 0, 10), 10);
    });

    test('tolera min > max sin lanzar', () {
      expect(safeClamp(5, 10, 0), 5);
      expect(safeClamp(-1, 10, 0), 0);
      expect(safeClamp(99, 10, 0), 10);
    });

    test('maneja no finitos', () {
      expect(safeClamp(double.nan, 1, 3), 1);
      expect(safeClamp(double.infinity, 1, 3), 3);
      expect(safeClamp(2, double.nan, 3), 2);
    });
  });
}
