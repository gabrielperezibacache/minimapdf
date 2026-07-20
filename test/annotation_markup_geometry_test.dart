import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:minimal_pdf/presentation/providers/reader_annotations_provider.dart';
import 'package:minimal_pdf/presentation/reader/annotation_markup_geometry.dart';

void main() {
  const page = Size(400, 800);

  group('computeMarkupRect highlight', () {
    test('toque crea marca corta centrada, no un blob ancho', () {
      final rect = computeMarkupRect(
        tool: AnnotationTool.highlight,
        canvasSize: page,
        start: const Offset(200, 400),
        end: const Offset(200, 400),
        fromDrag: false,
      );

      expect(rect.width, closeTo(kTapMarkupWidth, 0.001));
      expect(rect.width, lessThan(0.2));
      expect(rect.height, closeTo(kMarkupLineHeight, 0.001));
      expect(rect.x + rect.width / 2, closeTo(0.5, 0.01));
      expect(rect.y + rect.height / 2, closeTo(0.5, 0.01));
    });

    test('arrastre horizontal sigue el trazo en X y una sola línea en Y', () {
      final rect = computeMarkupRect(
        tool: AnnotationTool.highlight,
        canvasSize: page,
        start: const Offset(40, 200),
        end: const Offset(280, 208),
        fromDrag: true,
      );

      expect(rect.x, closeTo(40 / 400, 0.01));
      expect(rect.width, closeTo(240 / 400, 0.01));
      expect(rect.height, lessThanOrEqualTo(kMarkupLineHeight * 1.6));
      final midY = (200 + 208) / 2 / 800;
      expect(rect.y + rect.height / 2, closeTo(midY, 0.02));
    });

    test('arrastre vertical amplio cubre el área arrastrada', () {
      final rect = computeMarkupRect(
        tool: AnnotationTool.highlight,
        canvasSize: page,
        start: const Offset(50, 100),
        end: const Offset(300, 260),
        fromDrag: true,
      );

      expect(rect.x, closeTo(50 / 400, 0.01));
      expect(rect.y, closeTo(100 / 800, 0.01));
      expect(rect.width, closeTo(250 / 400, 0.01));
      expect(rect.height, closeTo(160 / 800, 0.01));
    });
  });

  group('computeMarkupRect underline', () {
    test('arrastre produce trazo fino bajo la línea', () {
      final rect = computeMarkupRect(
        tool: AnnotationTool.underline,
        canvasSize: page,
        start: const Offset(60, 300),
        end: const Offset(300, 305),
        fromDrag: true,
      );

      expect(rect.width, closeTo(240 / 400, 0.01));
      expect(rect.height, closeTo(kUnderlineStrokeHeight, 0.001));
      final midY = (300 + 305) / 2 / 800;
      expect(rect.y, greaterThan(midY));
    });

    test('toque no inventa un subrayado enorme', () {
      final rect = computeMarkupRect(
        tool: AnnotationTool.underline,
        canvasSize: page,
        start: const Offset(100, 400),
        end: const Offset(100, 400),
        fromDrag: false,
      );

      expect(rect.width, closeTo(kTapMarkupWidth, 0.001));
      expect(rect.height, closeTo(kUnderlineStrokeHeight, 0.001));
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
