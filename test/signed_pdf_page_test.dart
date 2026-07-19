import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:minimal_pdf/core/theme/app_theme.dart';
import 'package:minimal_pdf/core/theme/app_theme_option.dart';
import 'package:minimal_pdf/data/models/document_signature.dart';
import 'package:minimal_pdf/data/models/signature_type.dart';
import 'package:minimal_pdf/presentation/reader/widgets/signed_pdf_page.dart';
import 'package:minimal_pdf/presentation/signing/signature_overlay.dart';
import 'package:pdfx/pdfx.dart';

class _FakePageImage extends PdfPageImage {
  _FakePageImage(Uint8List bytes)
      : super(
          id: 'fake',
          pageNumber: 1,
          width: 200,
          height: 300,
          bytes: bytes,
          format: PdfPageImageFormat.png,
          quality: 100,
        );

  @override
  bool operator ==(Object other) => identical(this, other);

  @override
  int get hashCode => identityHashCode(this);
}

void main() {
  testWidgets('SignedPdfPage ancla SignatureLayer a la página', (tester) async {
    // PNG 1x1 mínimo válido.
    final png = Uint8List.fromList(<int>[
      0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D,
      0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
      0x08, 0x02, 0x00, 0x00, 0x00, 0x90, 0x77, 0x53, 0xDE, 0x00, 0x00, 0x00,
      0x0C, 0x49, 0x44, 0x41, 0x54, 0x08, 0xD7, 0x63, 0xF8, 0xCF, 0xC0, 0x00,
      0x00, 0x00, 0x03, 0x00, 0x01, 0x00, 0x05, 0xFE, 0xD4, 0xEF, 0x00, 0x00,
      0x00, 0x00, 0x49, 0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82,
    ]);

    final signature = DocumentSignature(
      id: 1,
      bookId: 1,
      pageNumber: 1,
      type: SignatureType.typed,
      signerName: 'Ana',
      typedText: 'Ana',
      offsetX: 0,
      offsetY: 0,
      signedAt: DateTime.utc(2026, 7, 19),
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.of(AppThemeOption.ebony),
        home: Scaffold(
          body: SignedPdfPage(
            pageImageFuture: Future<_FakePageImage>.value(_FakePageImage(png)),
            pageNumber: 1,
            signatures: [signature],
            ebonyFilter: false,
            placementMode: false,
            onPlaceTap: (_, _) {},
            onMove: (_, _, _) {},
            onDelete: (_) {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(SignatureOverlay), findsOneWidget);
    expect(find.textContaining('Firmante'), findsOneWidget);
  });
}
