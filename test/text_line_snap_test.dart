import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:minimal_pdf/presentation/reader/text_line_snap.dart';

void main() {
  group('detectTextBands', () {
    test('detecta dos bandas separadas por un hueco', () {
      // Perfil: texto (alto), hueco (bajo), texto (alto).
      final profile = <double>[
        ...List.filled(20, 0.05), // margen superior
        ...List.filled(20, 0.8), // línea 1
        ...List.filled(20, 0.05), // interlínea
        ...List.filled(20, 0.8), // línea 2
        ...List.filled(20, 0.05), // margen inferior
      ];
      final bands = detectTextBands(profile);
      expect(bands.length, 2);
      expect(bands[0].center, lessThan(0.5));
      expect(bands[1].center, greaterThan(0.5));
    });

    test('perfil plano no produce bandas', () {
      final bands = detectTextBands(List.filled(100, 0.3));
      expect(bands, isEmpty);
    });
  });

  group('snapStrokeToBands', () {
    final bands = [
      const TextBand(top: 0.30, bottom: 0.40),
      const TextBand(top: 0.60, bottom: 0.70),
    ];

    test('marcado se alinea al centro de la banda más cercana', () {
      final stroke = [
        [0.2, 0.34],
        [0.5, 0.36],
        [0.8, 0.33],
      ];
      final snapped = snapStrokeToBands(
        stroke: stroke,
        bands: bands,
        underline: false,
      );
      expect(snapped, isNotNull);
      expect(snapped!.length, 2);
      // Ambos puntos a la misma y = centro de la banda 0 (0.35).
      expect(snapped[0][1], closeTo(0.35, 1e-9));
      expect(snapped[1][1], closeTo(0.35, 1e-9));
      // Conserva el rango x del trazo.
      expect(snapped[0][0], closeTo(0.2, 1e-9));
      expect(snapped[1][0], closeTo(0.8, 1e-9));
    });

    test('subrayado se alinea al borde inferior de la banda', () {
      final stroke = [
        [0.2, 0.63],
        [0.8, 0.66],
      ];
      final snapped = snapStrokeToBands(
        stroke: stroke,
        bands: bands,
        underline: true,
      );
      expect(snapped, isNotNull);
      expect(snapped![0][1], closeTo(0.70, 1e-9));
    });

    test('devuelve null si no hay banda cercana', () {
      final stroke = [
        [0.2, 0.02],
        [0.8, 0.03],
      ];
      final snapped = snapStrokeToBands(
        stroke: stroke,
        bands: bands,
        underline: false,
        maxDistance: 0.05,
      );
      expect(snapped, isNull);
    });
  });

  group('straightenStroke', () {
    test('marcado usa la y media y el rango x completo', () {
      final stroke = [
        [0.1, 0.50],
        [0.5, 0.54],
        [0.9, 0.52],
      ];
      final s = straightenStroke(stroke: stroke, underline: false);
      expect(s[0][0], closeTo(0.1, 1e-9));
      expect(s[1][0], closeTo(0.9, 1e-9));
      expect(s[0][1], closeTo(0.52, 1e-9));
      expect(s[0][1], equals(s[1][1]));
    });
  });

  group('inkProfileFromRgba', () {
    test('filas oscuras producen mayor densidad de tinta', () {
      const w = 4;
      const h = 4;
      final rgba = Uint8List(w * h * 4);
      // Fila 0 negra, resto blanco.
      for (var y = 0; y < h; y++) {
        for (var x = 0; x < w; x++) {
          final i = (y * w + x) * 4;
          final v = y == 0 ? 0 : 255;
          rgba[i] = v;
          rgba[i + 1] = v;
          rgba[i + 2] = v;
          rgba[i + 3] = 255;
        }
      }
      final profile = inkProfileFromRgba(rgba, w, h, buckets: 4, colStride: 1);
      expect(profile.length, 4);
      expect(profile[0], greaterThan(0.9)); // fila negra
      expect(profile[3], lessThan(0.1)); // fila blanca
    });
  });
}
