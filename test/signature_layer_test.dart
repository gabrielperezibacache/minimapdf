import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:minimal_pdf/core/theme/app_theme.dart';
import 'package:minimal_pdf/core/theme/app_theme_option.dart';
import 'package:minimal_pdf/data/models/document_signature.dart';
import 'package:minimal_pdf/data/models/signature_type.dart';
import 'package:minimal_pdf/presentation/signing/signature_overlay.dart';

void main() {
  testWidgets('SignatureLayer coloca el sello según offset relativo', (tester) async {
    final signature = DocumentSignature(
      id: 1,
      bookId: 1,
      pageNumber: 1,
      type: SignatureType.typed,
      signerName: 'Ana',
      typedText: 'Ana',
      offsetX: 0.0,
      offsetY: 0.0,
      signedAt: DateTime.utc(2026, 7, 19, 12),
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.of(AppThemeOption.obsidian),
        home: Scaffold(
          body: SizedBox(
            width: 400,
            height: 700,
            child: SignatureLayer(
              signatures: [signature],
              topReserve: 0,
              bottomReserve: 0,
              onMove: (signature, x, y) {},
              onDelete: (signature) {},
            ),
          ),
        ),
      ),
    );

    final overlay = find.byType(SignatureOverlay);
    expect(overlay, findsOneWidget);

    final topLeft = tester.getTopLeft(overlay);
    expect(topLeft.dx, closeTo(0, 0.5));
    expect(topLeft.dy, closeTo(0, 0.5));
    expect(find.textContaining('Firmante'), findsOneWidget);
    expect(find.text('Ana'), findsWidgets);
  });

  testWidgets('SignatureLayer invoca onMove al arrastrar', (tester) async {
    DocumentSignature? moved;
    var nextX = -1.0;
    var nextY = -1.0;

    final signature = DocumentSignature(
      id: 7,
      bookId: 1,
      pageNumber: 1,
      type: SignatureType.typed,
      signerName: 'Luis',
      typedText: 'Luis',
      offsetX: 0.2,
      offsetY: 0.2,
      signedAt: DateTime.utc(2026, 7, 19, 12),
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.of(AppThemeOption.obsidian),
        home: Scaffold(
          body: SizedBox(
            width: 400,
            height: 700,
            child: SignatureLayer(
              signatures: [signature],
              onMove: (sig, x, y) {
                moved = sig;
                nextX = x;
                nextY = y;
              },
              onDelete: (_) {},
            ),
          ),
        ),
      ),
    );

    final overlay = find.byType(SignatureOverlay);
    await tester.drag(overlay, const Offset(80, 60));
    await tester.pumpAndSettle();

    expect(moved?.id, 7);
    expect(nextX, greaterThan(0.2));
    expect(nextY, greaterThan(0.2));
  });
}
