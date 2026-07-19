import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:minimal_pdf/core/theme/app_theme.dart';
import 'package:minimal_pdf/core/theme/app_theme_option.dart';
import 'package:minimal_pdf/data/models/signature_type.dart';
import 'package:minimal_pdf/domain/electronic_signature_service.dart';
import 'package:minimal_pdf/presentation/signing/signature_sheet.dart';

void main() {
  testWidgets('showSignatureSheet valida firmante vacío', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.of(AppThemeOption.obsidian),
        home: Builder(
          builder: (context) {
            return Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () => showSignatureSheet(
                    context,
                    pageNumber: 2,
                  ),
                  child: const Text('Abrir'),
                ),
              ),
            );
          },
        ),
      ),
    );

    await tester.tap(find.text('Abrir'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Firmar'));
    await tester.pumpAndSettle();

    expect(find.text('Indica el nombre del firmante.'), findsOneWidget);
    expect(find.text('Firmar documento · página 2'), findsOneWidget);
  });

  testWidgets('showSignatureSheet devuelve borrador mecanografiado', (tester) async {
    SignatureDraft? draft;

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.of(AppThemeOption.obsidian),
        home: Builder(
          builder: (context) {
            return Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () async {
                    draft = await showSignatureSheet(
                      context,
                      pageNumber: 1,
                      initialSignerName: 'Laura',
                    );
                  },
                  child: const Text('Abrir'),
                ),
              ),
            );
          },
        ),
      ),
    );

    await tester.tap(find.text('Abrir'));
    await tester.pumpAndSettle();

    expect(find.text('Laura'), findsWidgets);

    await tester.tap(find.text('Firmar'));
    await tester.pumpAndSettle();

    expect(draft, isNotNull);
    expect(draft!.type, SignatureType.typed);
    expect(draft!.signerName, 'Laura');
    expect(draft!.typedText, 'Laura');
  });
}
