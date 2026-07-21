import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:minimal_pdf/presentation/providers/reader_annotations_provider.dart';
import 'package:minimal_pdf/presentation/reader/annotation_ink.dart';
import 'package:minimal_pdf/presentation/reader/annotation_markup_geometry.dart';

void main() {
  const page = Size(400, 800);

  group('normalizePixelStroke / boundingRect', () {
    test('toque sin arrastre no crea marca', () {
      expect(
        normalizePixelStroke(
          canvasSize: page,
          points: const [Offset(200, 400)],
        ),
        isNull,
      );
      expect(
        computeMarkupRect(
          tool: AnnotationTool.highlight,
          canvasSize: page,
          points: const [Offset(200, 400)],
        ),
        isNull,
      );
    });

    test('microgesto no crea marca', () {
      expect(
        computeMarkupRect(
          tool: AnnotationTool.highlight,
          canvasSize: page,
          points: const [Offset(200, 400), Offset(203, 401)],
        ),
        isNull,
      );
    });

    test('arrastre horizontal sigue el path exacto (sin forzar altura de línea)',
        () {
      final points = const [
        Offset(40, 200),
        Offset(120, 202),
        Offset(200, 199),
        Offset(280, 203),
      ];
      final stroke = normalizePixelStroke(canvasSize: page, points: points);
      expect(stroke, isNotNull);
      expect(stroke!.length, greaterThanOrEqualTo(2));
      expect(stroke.first[0], closeTo(40 / 400, 0.01));
      expect(stroke.last[0], closeTo(280 / 400, 0.01));
      // Y del path ~200/800, no reubicado a “línea de texto”.
      expect(stroke.first[1], closeTo(200 / 800, 0.01));

      final rect = boundingRectForStroke(
        tool: AnnotationTool.highlight,
        canvasSize: page,
        stroke: stroke,
      );
      expect(rect, isNotNull);
      expect(rect!.x, lessThan(40 / 400));
      expect(rect.x + rect.width, greaterThan(280 / 400));
      // Altura = span del trazo + padding del resaltador, no una caja inventada.
      expect(rect.height, lessThan(0.08));
    });

    test('arrastre diagonal respeta el área recorrida', () {
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
      expect(rect!.width, greaterThan(0.5));
      expect(rect.height, greaterThan(0.15));
      expect(rect.y, lessThan(100 / 800 + 0.05));
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

  group('underline stroke', () {
    test('arrastre produce bbox del path (no rect bajo la línea)', () {
      final stroke = normalizePixelStroke(
        canvasSize: page,
        points: const [
          Offset(60, 300),
          Offset(180, 302),
          Offset(300, 301),
        ],
      );
      expect(stroke, isNotNull);
      final rect = boundingRectForStroke(
        tool: AnnotationTool.underline,
        canvasSize: page,
        stroke: stroke!,
      );
      expect(rect, isNotNull);
      expect(rect!.width, greaterThan(0.5));
      // Centrado cerca del path (~300 px), no desplazado bajo la “línea”.
      expect(rect.y + rect.height / 2, closeTo(301 / 800, 0.03));
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

  test('encode/decode ink round-trip', () {
    const strokes = [
      [
        [0.1, 0.2],
        [0.3, 0.25],
        [0.5, 0.22],
      ],
    ];
    final json = encodeAnnotationInk(strokes);
    final decoded = decodeAnnotationInk(json);
    expect(decoded, hasLength(1));
    expect(decoded.first, hasLength(3));
    expect(decoded.first[1][0], closeTo(0.3, 1e-9));
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
