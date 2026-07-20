import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:minimal_pdf/core/database/app_database.dart';
import 'package:minimal_pdf/core/database/library_database.dart';
import 'package:minimal_pdf/data/datasources/library_local_datasource.dart';
import 'package:minimal_pdf/data/models/book.dart';
import 'package:minimal_pdf/data/models/signature_role.dart';
import 'package:minimal_pdf/data/models/signature_type.dart';
import 'package:minimal_pdf/domain/electronic_signature_service.dart';
import 'package:minimal_pdf/l10n/app_message_keys.dart';
import 'package:minimal_pdf/presentation/providers/document_signing_provider.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

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
    tempDir = await Directory.systemTemp.createTemp('minimal_pdf_sign_');
    appDatabase = AppDatabase(
      customFactory: databaseFactoryFfi,
      databasePath: p.join(tempDir.path, 'library.db'),
    );
    await appDatabase.open();
    datasource = LibraryLocalDatasource(LibraryDatabase(appDatabase));
    book = await datasource.insertBook(
      Book(
        title: 'Contrato',
        filePath: p.join(tempDir.path, 'contrato.pdf'),
        fileSize: 12,
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

  test('signPage persiste firma mecanografiada', () async {
    final saved = await signing.signPage(
      pageNumber: 1,
      draft: const SignatureDraft(
        type: SignatureType.typed,
        signerName: 'María Gómez',
        typedText: 'M. Gómez',
      ),
    );

    expect(saved, isNotNull);
    expect(saved!.id, isNotNull);
    expect(signing.signaturesForPage(1), hasLength(1));
    expect(signing.signaturesForPage(1).first.displayText, 'M. Gómez');
  });

  test('signPage persiste firma dibujada y permite borrarla', () async {
    final saved = await signing.signPage(
      pageNumber: 4,
      draft: const SignatureDraft(
        type: SignatureType.drawn,
        signerName: 'Carlos',
        inkStrokes: [
          [
            [0.2, 0.3],
            [0.5, 0.4],
            [0.8, 0.2],
          ],
        ],
      ),
    );

    expect(saved?.type, SignatureType.drawn);
    expect(signing.signaturesForPage(4), hasLength(1));

    await signing.deleteSignature(saved!);
    expect(signing.signaturesForPage(4), isEmpty);
  });

  test('signPage sin trazo deja error de validación', () async {
    final saved = await signing.signPage(
      pageNumber: 2,
      draft: const SignatureDraft(
        type: SignatureType.drawn,
        signerName: 'Carlos',
      ),
    );

    expect(saved, isNull);
    expect(signing.error, AppMessageKeys.errorDrawSignatureEmpty);
  });

  test('moveSignature actualiza offsets y lastSignerName', () async {
    final saved = await signing.signPage(
      pageNumber: 1,
      draft: const SignatureDraft(
        type: SignatureType.typed,
        signerName: 'Nora',
        typedText: 'Nora',
      ),
    );

    expect(signing.lastSignerName, 'Nora');

    await signing.moveSignature(
      signature: saved!,
      offsetX: 0.2,
      offsetY: 0.3,
    );

    final moved = signing.signaturesForPage(1).first;
    expect(moved.offsetX, closeTo(0.2, 0.001));
    expect(moved.offsetY, closeTo(0.3, 0.001));
  });

  test('lastSignerName usa la firma más reciente por fecha', () async {
    await signing.signPage(
      pageNumber: 1,
      draft: const SignatureDraft(
        type: SignatureType.typed,
        signerName: 'Antigua',
        typedText: 'Antigua',
      ),
    );
    await Future<void>.delayed(const Duration(milliseconds: 5));
    await signing.signPage(
      pageNumber: 3,
      draft: const SignatureDraft(
        type: SignatureType.typed,
        signerName: 'Reciente',
        typedText: 'Reciente',
      ),
    );

    expect(signing.lastSignerName, 'Reciente');
  });

  test('moveSignature ignora cambios insignificantes', () async {
    final saved = await signing.signPage(
      pageNumber: 1,
      draft: const SignatureDraft(
        type: SignatureType.typed,
        signerName: 'Eva',
        typedText: 'Eva',
      ),
    );

    final before = saved!.offsetX;
    await signing.moveSignature(
      signature: saved,
      offsetX: saved.offsetX + 0.0004,
      offsetY: saved.offsetY,
    );
    expect(signing.signaturesForPage(1).first.offsetX, before);
  });

  test('roles y orden de firma incrementan por documento', () async {
    final first = await signing.signPage(
      pageNumber: 1,
      draft: const SignatureDraft(
        type: SignatureType.typed,
        signerName: 'Ana',
        typedText: 'Ana',
        role: SignatureRole.signer,
      ),
    );
    final second = await signing.signPage(
      pageNumber: 1,
      draft: const SignatureDraft(
        type: SignatureType.typed,
        signerName: 'Bruno',
        typedText: 'Bruno',
        role: SignatureRole.witness,
        offsetX: 0.1,
        offsetY: 0.1,
      ),
    );

    expect(first!.signingOrder, 1);
    expect(first.role, SignatureRole.signer);
    expect(second!.signingOrder, 2);
    expect(second.role, SignatureRole.witness);
    expect(signing.lastRole, SignatureRole.witness);
  });

  test('guarda plantilla reutilizable al firmar', () async {
    final saved = await signing.signPage(
      pageNumber: 1,
      draft: const SignatureDraft(
        type: SignatureType.typed,
        signerName: 'Clara Ruiz',
        typedText: 'C. Ruiz',
        role: SignatureRole.reviewer,
        saveAsTemplate: true,
        templateName: 'Mi rúbrica',
      ),
    );

    expect(saved, isNotNull);
    expect(signing.templates, hasLength(1));
    expect(signing.templates.first.name, 'Mi rúbrica');
    expect(signing.templates.first.role, SignatureRole.reviewer);
    expect(signing.templates.first.displayText, 'C. Ruiz');
  });

  test('placement mode registra offsets y sale del modo', () async {
    signing.beginPlacementMode();
    expect(signing.placementMode, isTrue);

    signing.placeSignatureAt(offsetX: 0.25, offsetY: 0.75);
    expect(signing.placementMode, isFalse);
    expect(signing.pendingOffsetX, closeTo(0.25, 0.001));
    expect(signing.pendingOffsetY, closeTo(0.75, 0.001));

    final saved = await signing.signPage(
      pageNumber: 2,
      draft: const SignatureDraft(
        type: SignatureType.typed,
        signerName: 'Diego',
        typedText: 'Diego',
      ),
    );

    expect(saved!.offsetX, closeTo(0.25, 0.001));
    expect(saved.offsetY, closeTo(0.75, 0.001));
    expect(signing.pendingOffsetX, isNull);
  });
}
