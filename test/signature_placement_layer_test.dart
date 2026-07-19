import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:minimal_pdf/core/theme/app_theme.dart';
import 'package:minimal_pdf/core/theme/app_theme_option.dart';
import 'package:minimal_pdf/presentation/signing/signature_overlay.dart';

void main() {
  testWidgets('placementMode invoca onPlaceTap con coords normalizadas',
      (tester) async {
    double? tappedX;
    double? tappedY;

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.of(AppThemeOption.obsidian),
        home: Scaffold(
          body: SizedBox(
            width: 400,
            height: 700,
            child: SignatureLayer(
              signatures: const [],
              placementMode: true,
              topReserve: 0,
              bottomReserve: 0,
              onPlaceTap: (x, y) {
                tappedX = x;
                tappedY = y;
              },
              onMove: (_, _, _) {},
              onDelete: (_) {},
            ),
          ),
        ),
      ),
    );

    expect(find.text('Toca donde quieres colocar la firma'), findsOneWidget);

    await tester.tapAt(const Offset(100, 140));
    await tester.pump();

    expect(tappedX, isNotNull);
    expect(tappedY, isNotNull);
    expect(tappedX!, inInclusiveRange(0.0, 1.0));
    expect(tappedY!, inInclusiveRange(0.0, 1.0));
  });
}
