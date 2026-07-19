import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:minimal_pdf/core/theme/app_theme.dart';
import 'package:minimal_pdf/core/theme/app_theme_option.dart';
import 'package:minimal_pdf/presentation/signing/signature_pad.dart';

void main() {
  testWidgets('SignaturePad emite trazos normalizados al dibujar', (tester) async {
    List<List<List<double>>>? strokes;

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.of(AppThemeOption.obsidian),
        home: Scaffold(
          body: SignaturePad(
            onStrokesChanged: (value) => strokes = value,
          ),
        ),
      ),
    );

    final pad = find.byType(GestureDetector).last;
    final center = tester.getCenter(pad);

    final gesture = await tester.startGesture(center);
    await gesture.moveBy(const Offset(40, -20));
    await gesture.moveBy(const Offset(30, 10));
    await gesture.up();
    await tester.pump();

    expect(strokes, isNotNull);
    expect(strokes, isNotEmpty);
    expect(strokes!.first.length, greaterThanOrEqualTo(2));
    for (final point in strokes!.first) {
      expect(point[0], inInclusiveRange(0.0, 1.0));
      expect(point[1], inInclusiveRange(0.0, 1.0));
    }
  });

  testWidgets('SignaturePad limpia el trazo', (tester) async {
    var strokes = <List<List<double>>>[];

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.of(AppThemeOption.obsidian),
        home: Scaffold(
          body: SignaturePad(
            onStrokesChanged: (value) => strokes = value,
          ),
        ),
      ),
    );

    final pad = find.byType(GestureDetector).last;
    final center = tester.getCenter(pad);
    final gesture = await tester.startGesture(center);
    await gesture.moveBy(const Offset(50, 0));
    await gesture.up();
    await tester.pump();
    expect(strokes, isNotEmpty);

    await tester.tap(find.text('Limpiar'));
    await tester.pump();
    expect(strokes, isEmpty);
  });
}
