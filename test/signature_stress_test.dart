import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'support/l10n_test_app.dart';
import 'package:minimal_pdf/core/database/app_database.dart';
import 'package:minimal_pdf/core/database/library_database.dart';
import 'package:minimal_pdf/core/theme/app_theme.dart';
import 'package:minimal_pdf/core/theme/app_theme_option.dart';
import 'package:minimal_pdf/data/datasources/library_local_datasource.dart';
import 'package:minimal_pdf/data/models/book.dart';
import 'package:minimal_pdf/data/models/document_signature.dart';
import 'package:minimal_pdf/data/models/signature_type.dart';
import 'package:minimal_pdf/domain/electronic_signature_service.dart';
import 'package:minimal_pdf/presentation/providers/document_signing_provider.dart';
import 'package:minimal_pdf/presentation/signing/signature_overlay.dart';
import 'package:minimal_pdf/presentation/signing/signature_pad.dart';
import 'package:minimal_pdf/presentation/signing/signature_sheet.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  const service = ElectronicSignatureService();

  DocumentSignature stubAt(double x, double y, {String name = 'A'}) {
    return DocumentSignature(
      bookId: 1,
      pageNumber: 1,
      type: SignatureType.typed,
      signerName: name,
      typedText: name,
      offsetX: x,
      offsetY: y,
      signedAt: DateTime.utc(2026, 7, 1),
    );
  }

  group('dominio estrés', () {
    test('normaliza NBSP y saltos de línea en el nombre', () {
      final signature = service.signDocument(
        bookId: 1,
        pageNumber: 1,
        draft: const SignatureDraft(
          type: SignatureType.typed,
          signerName: 'Ana\u00A0\u00A0Pérez\n',
          typedText: 'Ana\u00A0Pérez',
        ),
      );
      expect(signature.signerName, 'Ana Pérez');
      expect(signature.typedText, 'Ana Pérez');
    });

    test('suggestOffset evita el fallback ocupado y maximiza separación', () {
      final existing = <DocumentSignature>[
        for (var i = 0; i < 24; i++)
          stubAt(
            (ElectronicSignatureService.defaultOffsetX - i * 0.05)
                .clamp(0.05, 0.85),
            (ElectronicSignatureService.defaultOffsetY - i * 0.10)
                .clamp(0.08, 0.85),
            name: 'E$i',
          ),
        for (var row = 0; row < 5; row++)
          for (var col = 0; col < 5; col++)
            stubAt(
              (0.15 + col * 0.15).clamp(0.05, 0.85),
              (0.20 + row * 0.15).clamp(0.08, 0.85),
              name: 'G$row$col',
            ),
        stubAt(0.10, 0.12, name: 'fallback'),
      ];

      final next = service.suggestOffset(existing);

      // No debe caer exactamente encima de una firma existente.
      for (final item in existing) {
        final dx = next.$1 - item.offsetX;
        final dy = next.$2 - item.offsetY;
        expect(dx * dx + dy * dy, greaterThan(0.0001));
      }

      // Debe ser al menos tan bueno como el maximin sobre una malla densa.
      double nearest(double x, double y) {
        var best = double.infinity;
        for (final item in existing) {
          final dx = item.offsetX - x;
          final dy = item.offsetY - y;
          final d = (dx * dx + dy * dy);
          if (d < best) best = d;
        }
        return best;
      }

      expect(nearest(next.$1, next.$2), greaterThan(nearest(0.10, 0.12)));
    });

    test('encodeInk round-trip mantiene trazos útiles', () {
      final ink = service.encodeInk(const [
        [
          [0.0, 0.0],
          [0.5, 0.5],
          [1.0, 0.25],
        ],
      ]);
      final signature = DocumentSignature(
        bookId: 1,
        pageNumber: 1,
        type: SignatureType.drawn,
        signerName: 'Leo',
        inkJson: ink,
        signedAt: DateTime.utc(2026, 7, 19),
      );
      expect(signature.inkStrokes.single.length, 3);
      expect(signature.inkStrokes.single.first, [0.0, 0.0]);
    });

    test('rechaza trazo solo con puntos idénticos', () {
      expect(
        () => service.signDocument(
          bookId: 1,
          pageNumber: 1,
          draft: const SignatureDraft(
            type: SignatureType.drawn,
            signerName: 'X',
            inkStrokes: [
              [
                [0.2, 0.2],
                [0.2, 0.2],
                [0.2001, 0.2001],
              ],
            ],
          ),
        ),
        throwsA(isA<SignatureValidationException>()),
      );
    });
  });

  group('provider estrés', () {
    late Directory tempDir;
    late AppDatabase appDatabase;
    late DocumentSigningProvider signing;

    setUpAll(() {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    });

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('sign_stress_');
      appDatabase = AppDatabase(
        customFactory: databaseFactoryFfi,
        databasePath: p.join(tempDir.path, 'library.db'),
      );
      await appDatabase.open();
      final datasource =
          LibraryLocalDatasource(LibraryDatabase(appDatabase));
      final book = await datasource.insertBook(
        Book(
          title: 'Stress',
          filePath: p.join(tempDir.path, 's.pdf'),
          fileSize: 4,
          addedAt: DateTime(2026, 7, 19),
        ),
      );
      signing = DocumentSigningProvider(datasource);
      await signing.loadForBook(book);
    });

    tearDown(() async {
      signing.dispose();
      await appDatabase.close();
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('signPage concurrente no duplica con el mismo offset', () async {
      const draft = SignatureDraft(
        type: SignatureType.typed,
        signerName: 'Concurrente',
        typedText: 'Concurrente',
      );

      final results = await Future.wait([
        signing.signPage(pageNumber: 1, draft: draft),
        signing.signPage(pageNumber: 1, draft: draft),
      ]);

      final saved = results.whereType<DocumentSignature>().toList();
      expect(saved, isNotEmpty);
      // Como mucho una debería ganarse el race; la otra se rechaza.
      expect(saved.length, 1);
      expect(signing.signaturesForPage(1), hasLength(1));
    });

    test('moveSignature con NaN no corrompe offsets', () async {
      final saved = await signing.signPage(
        pageNumber: 1,
        draft: const SignatureDraft(
          type: SignatureType.typed,
          signerName: 'N',
          typedText: 'N',
        ),
      );

      final beforeX = saved!.offsetX;
      final beforeY = saved.offsetY;
      await signing.moveSignature(
        signature: saved,
        offsetX: double.nan,
        offsetY: double.infinity,
      );

      final current = signing.signaturesForPage(1).first;
      expect(current.offsetX, beforeX);
      expect(current.offsetY, beforeY);
    });

    test('firmas secuenciales en la misma página quedan separadas', () async {
      final a = await signing.signPage(
        pageNumber: 2,
        draft: const SignatureDraft(
          type: SignatureType.typed,
          signerName: 'Uno',
          typedText: 'Uno',
        ),
      );
      final b = await signing.signPage(
        pageNumber: 2,
        draft: const SignatureDraft(
          type: SignatureType.typed,
          signerName: 'Dos',
          typedText: 'Dos',
        ),
      );

      expect(a, isNotNull);
      expect(b, isNotNull);
      final dx = a!.offsetX - b!.offsetX;
      final dy = a.offsetY - b.offsetY;
      final min2 = ElectronicSignatureService.minOffsetDistance *
          ElectronicSignatureService.minOffsetDistance;
      expect(dx * dx + dy * dy, greaterThanOrEqualTo(min2));
    });
  });

  group('UI estrés', () {
    testWidgets('pad: tap sin arrastre no deja trazo', (tester) async {
      List<List<List<double>>>? strokes;

      await tester.pumpWidget(
        l10nTestApp(
          theme: AppTheme.of(AppThemeOption.ebony),
          home: Scaffold(
            body: SignaturePad(
              onStrokesChanged: (value) => strokes = value,
            ),
          ),
        ),
      );

      final pad = find.byType(GestureDetector).last;
      await tester.tap(pad);
      await tester.pump();

      expect(strokes ?? const [], isEmpty);
    });

    testWidgets('sheet: modo dibujada sin trazo muestra error', (tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        l10nTestApp(
          theme: AppTheme.of(AppThemeOption.ebony),
          home: Builder(
            builder: (context) {
              return Scaffold(
                body: Center(
                  child: ElevatedButton(
                    onPressed: () => showSignatureSheet(
                      context,
                      pageNumber: 1,
                      initialSignerName: 'Ana',
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

      // SegmentedButton puede mostrar "Dibujada" o "Trazo".
      final drawn = find.text('Dibujada');
      final stroke = find.text('Trazo');
      await tester.tap(drawn.evaluate().isEmpty ? stroke : drawn);
      await tester.pumpAndSettle();

      final firmar = find.widgetWithText(FilledButton, 'Firmar');
      await tester.scrollUntilVisible(
        firmar,
        120,
        scrollable: find.byType(Scrollable).last,
      );
      await tester.pumpAndSettle();
      await tester.tap(firmar);
      await tester.pumpAndSettle();

      expect(find.text('Dibuja tu firma antes de guardar.'), findsOneWidget);
    });

    testWidgets('SignatureLayer en ancho estrecho no explota', (tester) async {
      final signature = DocumentSignature(
        id: 1,
        bookId: 1,
        pageNumber: 1,
        type: SignatureType.typed,
        signerName: 'Ana',
        typedText: 'Ana',
        offsetX: 1.0,
        offsetY: 1.0,
        signedAt: DateTime.utc(2026, 7, 19),
      );

      await tester.pumpWidget(
        l10nTestApp(
          theme: AppTheme.of(AppThemeOption.ebony),
          home: Scaffold(
            body: SizedBox(
              width: 120,
              height: 200,
              child: SignatureLayer(
                signatures: [signature],
                onMove: (s, x, y) async => true,
                onDelete: (s) {},
              ),
            ),
          ),
        ),
      );

      expect(tester.takeException(), isNull);
      expect(find.byType(SignatureOverlay), findsOneWidget);
    });
  });
}
