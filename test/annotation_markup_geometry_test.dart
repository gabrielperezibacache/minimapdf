import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:minimal_pdf/presentation/providers/reader_annotations_provider.dart';
import 'package:minimal_pdf/presentation/reader/annotation_markup_geometry.dart';

void main() {
  const page = Size(400, 800);

  group('computeMarkupRect highlight', () {
    test('toque sin arrastre no crea marca', () {
      final rect = computeMarkupRect(
        tool: AnnotationTool.highlight,
        canvasSize: page,
        points: const [Offset(200, 400)],
      );
      expect(rect, isNull);
    });

    test('microgesto no crea marca', () {
      final rect = computeMarkupRect(
        tool: AnnotationTool.highlight,
        canvasSize: page,
        points: const [Offset(200, 400), Offset(203, 401)],
      );
      expect(rect, isNull);
    });

    test('arrastre horizontal sigue el trazo en X y una sola línea en Y', () {
      final rect = computeMarkupRect(
        tool: AnnotationTool.highlight,
        canvasSize: page,
        points: const [
          Offset(40, 200),
          Offset(120, 202),
          Offset(200, 199),
          Offset(280, 203),
        ],
      );

      expect(rect, isNotNull);
      expect(rect!.x, closeTo(40 / 400, 0.01));
      expect(rect.width, closeTo(240 / 400, 0.02));
      expect(rect.height, lessThanOrEqualTo(0.04));
      // Centrado cerca del ancla del trazo (~200 px).
      expect(rect.y + rect.height / 2, closeTo(200 / 800, 0.03));
    });

    test('arrastre vertical amplio cubre el área arrastrada', () {
      final rect = computeMarkupRect(
        tool: AnnotationTool.highlight,
        canvasSize: page,
        points: const [
          Offset(50, 100),
          Offset(180, 180),
          Offset(300, 260),
        ],
      );

      expect(rect, isNotNull);
      expect(rect!.x, closeTo(50 / 400, 0.01));
      expect(rect.width, closeTo(250 / 400, 0.02));
      expect(rect.height, greaterThan(0.15));
      expect(rect.y, lessThan(100 / 800 + 0.02));
    });

    test('resultado queda dentro de la página', () {
      final rect = computeMarkupRect(
        tool: AnnotationTool.highlight,
        canvasSize: page,
        points: const [
          Offset(-10, 5),
          Offset(50, 8),
        ],
      );
      expect(rect, isNotNull);
      expect(rect!.x, greaterThanOrEqualTo(0));
      expect(rect.y, greaterThanOrEqualTo(0));
      expect(rect.x + rect.width, lessThanOrEqualTo(1.0));
      expect(rect.y + rect.height, lessThanOrEqualTo(1.0));
    });
  });

  group('computeMarkupRect underline', () {
    test('arrastre produce trazo fino bajo la línea', () {
      final rect = computeMarkupRect(
        tool: AnnotationTool.underline,
        canvasSize: page,
        points: const [
          Offset(60, 300),
          Offset(180, 302),
          Offset(300, 301),
        ],
      );

      expect(rect, isNotNull);
      expect(rect!.width, closeTo(240 / 400, 0.02));
      expect(rect.height, lessThan(0.02));
      expect(rect.y, greaterThan(300 / 800));
    });

    test('toque no crea subrayado', () {
      final rect = computeMarkupRect(
        tool: AnnotationTool.underline,
        canvasSize: page,
        points: const [Offset(100, 400)],
      );
      expect(rect, isNull);
    });
  });

  test('computePinRect centra el pin en el toque', () {
    final rect = computePinRect(
      canvasSize: page,
      point: const Offset(200, 400),
    );
    expect(rect.x + rect.width / 2, closeTo(0.5, 0.01));
    expect(rect.y + rect.height / 2, closeTo(0.5, 0.01));
  });
}
