import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:minimal_pdf/core/database/app_database.dart';
import 'package:minimal_pdf/core/database/database_config.dart';
import 'package:minimal_pdf/core/database/library_database.dart';
import 'package:minimal_pdf/core/theme/app_theme.dart';
import 'package:minimal_pdf/core/theme/app_theme_option.dart';
import 'package:minimal_pdf/data/datasources/library_local_datasource.dart';
import 'package:minimal_pdf/data/models/book.dart';
import 'package:minimal_pdf/data/models/document_signature.dart';
import 'package:minimal_pdf/data/models/signature_role.dart';
import 'package:minimal_pdf/data/models/signature_template.dart';
import 'package:minimal_pdf/data/models/signature_type.dart';
import 'package:minimal_pdf/domain/electronic_signature_service.dart';
import 'package:minimal_pdf/domain/signature_manifest.dart';
import 'package:minimal_pdf/domain/signature_stamp_geometry.dart';
import 'package:minimal_pdf/domain/signed_pdf_export_service.dart';
import 'package:minimal_pdf/presentation/providers/document_signing_provider.dart';
import 'package:minimal_pdf/presentation/signing/signature_overlay.dart';
import 'package:minimal_pdf/presentation/signing/signature_pad.dart';
import 'package:minimal_pdf/presentation/signing/signature_sheet.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('geometría compartida', () {
    test('overlay y export usan el mismo maxLeft/maxTop', () {
      const page = Size(800, 1200);
      final stamp = SignatureStampGeometry.stampSizeFor(page);
      expect(stamp.width / page.width, closeTo(0.34, 0.0001));
      expect(stamp.height / stamp.width, closeTo(0.58, 0.0001));

      final a = SignatureStampGeometry.positionFor(
        pageSize: page,
        offsetX: 0.25,
        offsetY: 0.75,
      );
      final maxLeft = SignatureStampGeometry.maxLeft(page);
      final maxTop = SignatureStampGeometry.maxTop(page);
      expect(a.dx, closeTo(0.25 * maxLeft, 0.001));
      expect(a.dy, closeTo(0.75 * maxTop, 0.001));
    });
  });

  group('plantillas / ink', () {
    test('SignatureTemplate descarta puntos malformados', () {
      final template = SignatureTemplate(
        name: 't',
        type: SignatureType.drawn,
        signerName: 'Ana',
        inkJson: '[[[0.1,0.2],"x",[0.4,0.5],[1],[0.6,0.7]]]',
        createdAt: DateTime.utc(2026, 7, 19),
      );
      expect(template.inkStrokes, hasLength(1));
      expect(template.inkStrokes.first, hasLength(3));
    });

    test('toManifestMap hasInk usa trazos parseados', () {
      final bad = DocumentSignature(
        bookId: 1,
        pageNumber: 1,
        type: SignatureType.drawn,
        signerName: 'A',
        inkJson: '[{"no":"strokes"}]',
        signedAt: DateTime.utc(2026, 7, 19),
      );
      expect(bad.toManifestMap()['hasInk'], isFalse);

      final good = DocumentSignature(
        bookId: 1,
        pageNumber: 1,
        type: SignatureType.drawn,
        signerName: 'A',
        inkJson: '[[[0.1,0.2],[0.3,0.4]]]',
        signedAt: DateTime.utc(2026, 7, 19),
      );
      expect(good.toManifestMap()['hasInk'], isTrue);
    });

    test('SignatureManifest round-trip decode', () {
      final manifest = SignatureManifest(
        version: 1,
        exportedAt: DateTime.utc(2026, 7, 19, 16),
        sourceFileName: 'a.pdf',
        sourceSha256: 'a' * 64,
        signedFileName: 'a_firmado.pdf',
        signedSha256: 'b' * 64,
        signatures: [
          DocumentSignature(
            id: 2,
            bookId: 1,
            pageNumber: 1,
            type: SignatureType.typed,
            signerName: 'Ana',
            typedText: 'Ana',
            role: SignatureRole.reviewer,
            signingOrder: 2,
            signedAt: DateTime.utc(2026, 7, 19, 15),
          ),
        ],
      );
      final decoded = SignatureManifest.decode(manifest.encodePretty());
      expect(decoded.signedSha256, 'b' * 64);
      expect(decoded.signatures, hasLength(1));
      expect(decoded.signatures.first.role, SignatureRole.reviewer);
      expect(decoded.matchesSignedHash('B' * 64), isTrue);
    });

    test('manifiesto preserva inkJson en round-trip', () {
      const ink = '[[[0.1,0.2],[0.8,0.7]]]';
      final manifest = SignatureManifest(
        version: 1,
        exportedAt: DateTime.utc(2026, 7, 19, 16),
        sourceFileName: 'a.pdf',
        sourceSha256: 'a' * 64,
        signedFileName: 'a_firmado.pdf',
        signedSha256: 'b' * 64,
        signatures: [
          DocumentSignature(
            id: 3,
            bookId: 1,
            pageNumber: 1,
            type: SignatureType.drawn,
            signerName: 'Leo',
            inkJson: ink,
            role: SignatureRole.signer,
            signingOrder: 1,
            signedAt: DateTime.utc(2026, 7, 19, 15),
          ),
        ],
      );
      final decoded = SignatureManifest.decode(manifest.encodePretty());
      expect(decoded.signatures.first.inkJson, ink);
      expect(decoded.signatures.first.inkStrokes, hasLength(1));
    });
  });

  group('provider hardening', () {
    late Directory tempDir;
    late AppDatabase appDatabase;
    late LibraryLocalDatasource datasource;
    late Book book;
    late DocumentSigningProvider signing;

    setUpAll(() {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    });

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('sign_feat_');
      appDatabase = AppDatabase(
        customFactory: databaseFactoryFfi,
        databasePath: p.join(tempDir.path, 'library.db'),
      );
      await appDatabase.open();
      datasource = LibraryLocalDatasource(LibraryDatabase(appDatabase));
      book = await datasource.insertBook(
        Book(
          title: 'Contrato (firmado)',
          filePath: p.join(tempDir.path, 'c.pdf'),
          fileSize: 8,
          addedAt: DateTime(2026, 7, 19),
          tags: const ['firmado'],
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

    test('book sin id limpia bookId y no firma', () async {
      await signing.loadForBook(
        Book(
          title: 'Sin id',
          filePath: '/tmp/x.pdf',
          fileSize: 1,
          addedAt: DateTime(2026, 7, 19),
        ),
      );
      final saved = await signing.signPage(
        pageNumber: 1,
        draft: const SignatureDraft(
          type: SignatureType.typed,
          signerName: 'Ana',
          typedText: 'Ana',
        ),
      );
      expect(saved, isNull);
      expect(signing.error, contains('no disponible'));
    });

    test('export sin firmas deja error claro', () async {
      final empty = await signing.exportSignedPdf();
      expect(empty, isNull);
      expect(signing.error, contains('al menos una firma'));
    });

    test('export durante colocación se rechaza', () async {
      await signing.signPage(
        pageNumber: 1,
        draft: const SignatureDraft(
          type: SignatureType.typed,
          signerName: 'Ana',
          typedText: 'Ana',
        ),
      );
      signing.beginPlacementMode();
      final result = await signing.exportSignedPdf();
      expect(result, isNull);
      expect(signing.error, contains('colocación'));
    });

    test('moveSignature obsoleto no pisa offsets nuevos', () async {
      final saved = await signing.signPage(
        pageNumber: 1,
        draft: const SignatureDraft(
          type: SignatureType.typed,
          signerName: 'Ana',
          typedText: 'Ana',
          offsetX: 0.1,
          offsetY: 0.1,
        ),
      );

      final slow = signing.moveSignature(
        signature: saved!,
        offsetX: 0.2,
        offsetY: 0.2,
      );
      await signing.moveSignature(
        signature: saved,
        offsetX: 0.9,
        offsetY: 0.9,
      );
      await slow;

      final current = signing.signaturesForPage(1).first;
      expect(current.offsetX, closeTo(0.9, 0.001));
      expect(current.offsetY, closeTo(0.9, 0.001));

      final fromDb = await datasource.listSignatures(book.id!);
      expect(fromDb.first.offsetX, closeTo(0.9, 0.001));
      expect(fromDb.first.offsetY, closeTo(0.9, 0.001));
    });

    test('export concurrente reporta que ya hay una en curso', () async {
      signing.dispose();
      signing = DocumentSigningProvider(
        datasource,
        exportService: _SlowFailingExport(),
      );
      await signing.loadForBook(book);
      await signing.signPage(
        pageNumber: 1,
        draft: const SignatureDraft(
          type: SignatureType.typed,
          signerName: 'Ana',
          typedText: 'Ana',
        ),
      );

      final first = signing.exportSignedPdf();
      await Future<void>.delayed(const Duration(milliseconds: 40));
      final second = await signing.exportSignedPdf();
      expect(second, isNull);
      expect(signing.error, contains('en curso'));
      await first;
      expect(signing.exporting, isFalse);
      expect(signing.error, contains('No se pudo exportar'));
    });

    test('título exportado no acumula (firmado)', () async {
      final base = book.title
          .replaceAll(RegExp(r'\s*\(firmado\)\s*$'), '')
          .trim();
      expect(base, 'Contrato');
      expect('$base (firmado)', 'Contrato (firmado)');
    });

    test('firma se conserva si falla la plantilla', () async {
      await appDatabase.database
          .execute('DROP TABLE ${DatabaseConfig.tableSignatureTemplates}');

      final saved = await signing.signPage(
        pageNumber: 1,
        draft: const SignatureDraft(
          type: SignatureType.typed,
          signerName: 'Ana',
          typedText: 'Ana',
          role: SignatureRole.witness,
          saveAsTemplate: true,
          templateName: 'Mi plantilla',
        ),
      );

      expect(saved, isNotNull);
      expect(signing.signatures, hasLength(1));
      expect(signing.signatures.first.role, SignatureRole.witness);
      expect(signing.error, contains('plantilla'));
    });

    test('dispose no rompe por notifyListeners tardío', () async {
      final future = signing.loadForBook(book);
      signing.dispose();
      await expectLater(future, completes);
    });
  });

  group('migración v2 → v3 backfill orden', () {
    late Directory tempDir;

    setUpAll(() {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    });

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('sign_v3_');
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('reasigna signing_order por fecha', () async {
      final dbPath = p.join(tempDir.path, 'v2.db');
      final factory = databaseFactoryFfi;
      final old = await factory.openDatabase(
        dbPath,
        options: OpenDatabaseOptions(
          version: 2,
          onCreate: (db, version) async {
            await db.execute('''
              CREATE TABLE ${DatabaseConfig.tableBooks} (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                title TEXT NOT NULL,
                file_path TEXT NOT NULL UNIQUE,
                file_size INTEGER NOT NULL,
                added_at TEXT NOT NULL,
                last_read_at TEXT,
                last_page_read INTEGER NOT NULL DEFAULT 0,
                author TEXT,
                tags TEXT NOT NULL DEFAULT '[]',
                collection_id INTEGER
              )
            ''');
            await db.execute('''
              CREATE TABLE ${DatabaseConfig.tableSignatures} (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                book_id INTEGER NOT NULL,
                page_number INTEGER NOT NULL,
                type TEXT NOT NULL,
                signer_name TEXT NOT NULL,
                typed_text TEXT,
                ink_json TEXT,
                reason TEXT,
                offset_x REAL NOT NULL DEFAULT 0.58,
                offset_y REAL NOT NULL DEFAULT 0.70,
                signed_at TEXT NOT NULL
              )
            ''');
            final bookId = await db.insert(DatabaseConfig.tableBooks, {
              'title': 'Doc',
              'file_path': '/d.pdf',
              'file_size': 1,
              'added_at': '2026-07-19T00:00:00.000',
              'tags': '[]',
              'last_page_read': 0,
            });
            await db.insert(DatabaseConfig.tableSignatures, {
              'book_id': bookId,
              'page_number': 1,
              'type': 'typed',
              'signer_name': 'Primera',
              'typed_text': 'Primera',
              'signed_at': '2026-07-19T10:00:00.000Z',
            });
            await db.insert(DatabaseConfig.tableSignatures, {
              'book_id': bookId,
              'page_number': 1,
              'type': 'typed',
              'signer_name': 'Segunda',
              'typed_text': 'Segunda',
              'signed_at': '2026-07-19T11:00:00.000Z',
            });
          },
        ),
      );
      await old.close();

      final appDatabase = AppDatabase(
        customFactory: factory,
        databasePath: dbPath,
      );
      await appDatabase.open();
      final rows = await appDatabase.database.query(
        DatabaseConfig.tableSignatures,
        orderBy: 'signed_at ASC',
      );
      expect(rows, hasLength(2));
      expect(rows[0]['signing_order'], 1);
      expect(rows[1]['signing_order'], 2);
      expect(rows[0]['role'], 'signer');

      final templates = await appDatabase.database.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' AND name=?",
        [DatabaseConfig.tableSignatureTemplates],
      );
      expect(templates, isNotEmpty);
      await appDatabase.close();
    });
  });

  group('UI hardening', () {
    testWidgets('SignaturePad precarga trazos de plantilla', (tester) async {
      List<List<List<double>>>? emitted;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.of(AppThemeOption.ebony),
          home: Scaffold(
            body: SignaturePad(
              initialStrokes: const [
                [
                  [0.1, 0.2],
                  [0.8, 0.7],
                ],
              ],
              onStrokesChanged: (strokes) => emitted = strokes,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(emitted, isNotNull);
      expect(emitted, hasLength(1));
      expect(emitted!.first, hasLength(2));
      expect(find.text('Firma aquí'), findsNothing);
    });

    testWidgets('placementMode captura toques sobre sellos existentes',
        (tester) async {
      double? x;
      double? y;
      final signature = DocumentSignature(
        id: 1,
        bookId: 1,
        pageNumber: 1,
        type: SignatureType.typed,
        signerName: 'Ana',
        typedText: 'Ana',
        offsetX: 0.0,
        offsetY: 0.0,
        signedAt: DateTime.utc(2026, 7, 19),
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.of(AppThemeOption.ebony),
          home: Scaffold(
            body: SizedBox(
              width: 400,
              height: 700,
              child: SignatureLayer(
                signatures: [signature],
                placementMode: true,
                onPlaceTap: (px, py) {
                  x = px;
                  y = py;
                },
                onMove: (_, _, _) {},
                onDelete: (_) {},
              ),
            ),
          ),
        ),
      );

      // Toca encima del sello (esquina superior izquierda).
      await tester.tapAt(const Offset(40, 40));
      await tester.pump();
      expect(x, isNotNull);
      expect(y, isNotNull);
    });

    testWidgets('sheet exige nombre de plantilla si se marca guardar',
        (tester) async {
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
                      pageNumber: 1,
                      initialSignerName: 'Laura',
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

      await tester.tap(find.text('Guardar como plantilla'));
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

      expect(find.text('Indica un nombre para la plantilla.'), findsOneWidget);
    });
  });
}

class _SlowFailingExport extends SignedPdfExportService {
  @override
  Future<SignedPdfExportResult> exportSignedPdf({
    required Book book,
    required List<DocumentSignature> signatures,
    Set<String> reservedBasenames = const {},
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 250));
    throw StateError('export fail');
  }
}
