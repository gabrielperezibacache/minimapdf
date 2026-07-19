import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:minimal_pdf/core/theme/app_theme.dart';
import 'package:minimal_pdf/core/theme/app_theme_option.dart';
import 'package:minimal_pdf/data/models/signature_type.dart';
import 'package:minimal_pdf/domain/electronic_signature_service.dart';
import 'package:minimal_pdf/presentation/signing/signature_sheet.dart';

Future<void> _tapSignButton(WidgetTester tester) async {
  final firmar = find.widgetWithText(FilledButton, 'Firmar');
  await tester.scrollUntilVisible(
    firmar,
    120,
    scrollable: find.byType(Scrollable).last,
  );
  await tester.pumpAndSettle();
  await tester.tap(firmar);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('showSignatureSheet valida firmante vacío', (tester) async {
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.of(AppThemeOption.ebony),
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

    await _tapSignButton(tester);

    expect(find.text('Indica el nombre del firmante.'), findsOneWidget);
    expect(find.text('Firmar documento · página 2'), findsOneWidget);
  });

  testWidgets('showSignatureSheet devuelve borrador mecanografiado', (tester) async {
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    SignatureDraft? draft;

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.of(AppThemeOption.ebony),
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

    await _tapSignButton(tester);

    expect(draft, isNotNull);
    expect(draft!.type, SignatureType.typed);
    expect(draft!.signerName, 'Laura');
    expect(draft!.typedText, 'Laura');
  });
}
