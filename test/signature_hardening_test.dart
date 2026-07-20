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
import 'package:minimal_pdf/data/models/signature_type.dart';
import 'package:minimal_pdf/domain/electronic_signature_service.dart';
import 'package:minimal_pdf/presentation/providers/document_signing_provider.dart';
import 'package:minimal_pdf/presentation/signing/signature_overlay.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  const service = ElectronicSignatureService();

  group('ink / modelo', () {
    test('inkStrokes descarta puntos inválidos sin inventar (0,0)', () {
      final signature = DocumentSignature(
        bookId: 1,
        pageNumber: 1,
        type: SignatureType.drawn,
        signerName: 'Leo',
        inkJson: '[[[0.1,0.2],"malo",[0.4,0.5],[1],[0.7,0.8]]]',
        signedAt: DateTime.utc(2026, 7, 19),
      );

      expect(signature.inkStrokes, [
        [
          [0.1, 0.2],
          [0.4, 0.5],
          [0.7, 0.8],
        ],
      ]);
    });

    test('inkJson corrupto no rompe y queda vacío', () {
      final signature = DocumentSignature(
        bookId: 1,
        pageNumber: 1,
        type: SignatureType.drawn,
        signerName: 'Leo',
        inkJson: '{no-json',
        signedAt: DateTime.utc(2026, 7, 19),
      );
      expect(signature.inkStrokes, isEmpty);
    });

    test('normalizeStrokes limita puntos por trazo', () {
      final dense = [
        for (var i = 0; i < 5000; i++) [i / 5000, (i % 50) / 50],
      ];
      final normalized = service.normalizeStrokes([dense]);
      expect(normalized, hasLength(1));
      expect(
        normalized.single.length,
        lessThanOrEqualTo(ElectronicSignatureService.maxPointsPerStroke),
      );
    });

    test('formatSignatureDate rellena ceros', () {
      expect(
        formatSignatureDate(DateTime(2026, 3, 4, 5, 6)),
        matches(RegExp(r'^\d{2}/\d{2}/2026 \d{2}:\d{2}$')),
      );
      expect(formatSignatureDate(DateTime(2026, 3, 4, 5, 6)).contains('04/03/2026'), isTrue);
    });
  });

  group('migración DB v1 → v2', () {
    late Directory tempDir;

    setUpAll(() {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    });

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('sign_mig_');
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('onUpgrade crea tabla document_signatures', () async {
      final dbPath = p.join(tempDir.path, 'old.db');
      final factory = databaseFactoryFfi;

      // Simula DB v1 sin tabla de firmas.
      final old = await factory.openDatabase(
        dbPath,
        options: OpenDatabaseOptions(
          version: 1,
          onCreate: (db, version) async {
            await db.execute('''
              CREATE TABLE ${DatabaseConfig.tableCollections} (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                name TEXT NOT NULL,
                created_at TEXT NOT NULL
              )
            ''');
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
              CREATE TABLE ${DatabaseConfig.tableBookmarks} (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                book_id INTEGER NOT NULL,
                page_number INTEGER NOT NULL,
                note_text TEXT,
                created_at TEXT NOT NULL
              )
            ''');
          },
        ),
      );
      await old.close();

      final appDatabase = AppDatabase(
        customFactory: factory,
        databasePath: dbPath,
      );
      await appDatabase.open();

      final tables = await appDatabase.database.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' AND name=?",
        [DatabaseConfig.tableSignatures],
      );
      expect(tables, isNotEmpty);

      final templateTables = await appDatabase.database.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' AND name=?",
        [DatabaseConfig.tableSignatureTemplates],
      );
      expect(templateTables, isNotEmpty);

      final columns = await appDatabase.database.rawQuery(
        'PRAGMA table_info(${DatabaseConfig.tableSignatures})',
      );
      final names = columns.map((row) => row['name'] as String).toSet();
      expect(names, contains('role'));
      expect(names, contains('signing_order'));

      final library = LibraryDatabase(appDatabase);
      final book = await library.createBook(
        Book(
          title: 'Migrado',
          filePath: '/m.pdf',
          fileSize: 1,
          addedAt: DateTime(2026, 7, 19),
        ),
      );
      final signature = await library.createSignature(
        DocumentSignature(
          bookId: book.id!,
          pageNumber: 1,
          type: SignatureType.typed,
          signerName: 'Ana',
          typedText: 'Ana',
          signedAt: DateTime.utc(2026, 7, 19),
        ),
      );
      expect(signature.id, isNotNull);
      expect(signature.role.storageValue, 'signer');
      expect(signature.signingOrder, 1);
      await appDatabase.close();
    });
  });

  group('provider / capa', () {
    late Directory tempDir;
    late AppDatabase appDatabase;
    late DocumentSigningProvider signing;
    late int bookId;

    setUpAll(() {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    });

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('sign_hard_');
      appDatabase = AppDatabase(
        customFactory: databaseFactoryFfi,
        databasePath: p.join(tempDir.path, 'library.db'),
      );
      await appDatabase.open();
      final datasource =
          LibraryLocalDatasource(LibraryDatabase(appDatabase));
      final book = await datasource.insertBook(
        Book(
          title: 'Hard',
          filePath: p.join(tempDir.path, 'h.pdf'),
          fileSize: 3,
          addedAt: DateTime(2026, 7, 19),
        ),
      );
      bookId = book.id!;
      signing = DocumentSigningProvider(datasource);
      await signing.loadForBookId(bookId);
    });

    tearDown(() async {
      signing.dispose();
      await appDatabase.close();
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('signPage + loadForBook en paralelo deja la firma persistida', () async {
      final savedFuture = signing.signPage(
        pageNumber: 1,
        draft: const SignatureDraft(
          type: SignatureType.typed,
          signerName: 'Race',
          typedText: 'Race',
        ),
      );
      final loadFuture = signing.loadForBookId(bookId);
      final saved = await savedFuture;
      await loadFuture;

      await signing.loadForBookId(bookId);
      expect(saved, isNotNull);
      expect(signing.signaturesForPage(1), isNotEmpty);
    });

    testWidgets('SignatureLayer con reservas mayores que la altura no explota',
        (tester) async {
      final signature = DocumentSignature(
        id: 1,
        bookId: 1,
        pageNumber: 1,
        type: SignatureType.typed,
        signerName: 'Ana',
        typedText: 'Ana',
        offsetX: 0.5,
        offsetY: 0.5,
        signedAt: DateTime.utc(2026, 7, 19),
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.of(AppThemeOption.ebony),
          home: Scaffold(
            body: SizedBox(
              width: 300,
              height: 80,
              child: SignatureLayer(
                signatures: [signature],
                topReserve: 60,
                bottomReserve: 60,
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
