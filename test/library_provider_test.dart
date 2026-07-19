import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:minimal_pdf/core/database/app_database.dart';
import 'package:minimal_pdf/core/database/library_database.dart';
import 'package:minimal_pdf/data/datasources/library_local_datasource.dart';
import 'package:minimal_pdf/data/datasources/pdf_import_service.dart';
import 'package:minimal_pdf/presentation/providers/library_provider.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late AppDatabase appDatabase;
  late LibraryLocalDatasource datasource;
  late LibraryProvider provider;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('minimal_pdf_lib_');
    appDatabase = AppDatabase(
      customFactory: databaseFactoryFfi,
      databasePath: p.join(tempDir.path, 'library.db'),
    );
    await appDatabase.open();
    datasource = LibraryLocalDatasource(LibraryDatabase(appDatabase));

    final sourcePdf = File(p.join(tempDir.path, 'source.pdf'));
    await sourcePdf.writeAsBytes(const [0x25, 0x50, 0x44, 0x46]); // %PDF

    final importService = PdfImportService(
      datasource,
      picker: () async => PickedPdfFile(
        sourcePath: sourcePdf.path,
        displayName: 'Clean Code.pdf',
        fileSize: 4,
      ),
      documentsDirectory: () async => tempDir,
    );

    provider = LibraryProvider(
      datasource: datasource,
      importService: importService,
    );
  });

  tearDown(() async {
    await appDatabase.close();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('importPdf copia el archivo y refresca la biblioteca', () async {
    final book = await provider.importPdf();

    expect(book, isNotNull);
    expect(book!.title.toLowerCase(), contains('clean'));
    expect(provider.books, isNotEmpty);
    expect(File(book.filePath).existsSync(), isTrue);
    expect(book.filePath, contains('${p.separator}library${p.separator}'));
  });

  test('updateBookMetadata persiste título, autor y tags', () async {
    final book = await provider.importPdf();
    await provider.updateBookMetadata(
      book: book!,
      title: 'Código Limpio',
      author: 'Robert C. Martin',
      tags: const ['software', 'craft'],
    );

    final updated = provider.books.single;
    expect(updated.title, 'Código Limpio');
    expect(updated.author, 'Robert C. Martin');
    expect(updated.tags, ['software', 'craft']);
  });

  test('createCollection y filtro por carpeta', () async {
    await provider.importPdf();
    final collection = await provider.createCollection('Ensayos');
    expect(collection, isNotNull);

    provider.selectCollection(collection!.id);
    expect(provider.visibleBooks, isEmpty);

    provider.selectCollection(null);
    expect(provider.visibleBooks, isNotEmpty);
  });

  test('deleteBook elimina registro y archivo del disco', () async {
    final book = await provider.importPdf();
    expect(book, isNotNull);
    expect(File(book!.filePath).existsSync(), isTrue);

    await provider.deleteBook(book);

    expect(provider.books, isEmpty);
    expect(File(book.filePath).existsSync(), isFalse);
  });

  test('updateBookMetadata puede asignar colección', () async {
    final book = await provider.importPdf();
    final collection = await provider.createCollection('Técnicos');

    await provider.updateBookMetadata(
      book: book!,
      title: book.title,
      author: null,
      tags: const [],
      collectionId: collection!.id,
    );

    expect(provider.books.single.collectionId, collection.id);

    provider.selectCollection(collection.id);
    expect(provider.visibleBooks, hasLength(1));
  });

  test('deleteCollection deja libros sin carpeta', () async {
    final book = await provider.importPdf();
    final collection = await provider.createCollection('Temporal');
    await provider.updateBookMetadata(
      book: book!,
      title: book.title,
      author: null,
      tags: const [],
      collectionId: collection!.id,
    );

    provider.selectCollection(collection.id);
    expect(provider.visibleBooks, hasLength(1));

    await provider.deleteCollection(collection);

    expect(provider.collections, isEmpty);
    expect(provider.selectedCollectionId, isNull);
    expect(provider.books.single.collectionId, isNull);
  });

  test('renameCollection actualiza el nombre', () async {
    final collection = await provider.createCollection('Borrador');
    final renamed = await provider.renameCollection(collection!, 'Final');
    expect(renamed?.name, 'Final');
    expect(provider.collections.single.name, 'Final');
  });

  test('setSearchQuery filtra por título autor y tags', () async {
    final book = await provider.importPdf();
    await provider.updateBookMetadata(
      book: book!,
      title: 'Patrones de Diseño',
      author: 'Gamma',
      tags: const ['oop', 'gof'],
    );

    provider.setSearchQuery('patrones');
    expect(provider.visibleBooks, hasLength(1));

    provider.setSearchQuery('gamma');
    expect(provider.visibleBooks, hasLength(1));

    provider.setSearchQuery('gof');
    expect(provider.visibleBooks, hasLength(1));

    provider.setSearchQuery('inexistente');
    expect(provider.visibleBooks, isEmpty);

    provider.clearSearch();
    expect(provider.visibleBooks, hasLength(1));
  });

  test('bookFileExists refleja el archivo en disco', () async {
    final book = await provider.importPdf();
    expect(await provider.bookFileExists(book!), isTrue);

    await File(book.filePath).delete();
    expect(await provider.bookFileExists(book), isFalse);
  });

  test('importPdf concurrente se ignora si ya hay importación', () async {
    Future<PickedPdfFile?> slowPicker() async {
      await Future<void>.delayed(const Duration(milliseconds: 80));
      final sourcePdf = File(p.join(tempDir.path, 'slow.pdf'));
      await sourcePdf.writeAsBytes(const [0x25, 0x50, 0x44, 0x46]);
      return PickedPdfFile(
        sourcePath: sourcePdf.path,
        displayName: 'Slow.pdf',
        fileSize: 4,
      );
    }

    final slowProvider = LibraryProvider(
      datasource: datasource,
      importService: PdfImportService(
        datasource,
        picker: slowPicker,
        documentsDirectory: () async => tempDir,
      ),
    );

    final first = slowProvider.importPdf();
    await Future<void>.delayed(const Duration(milliseconds: 10));
    final second = await slowProvider.importPdf();
    expect(second, isNull);
    final book = await first;
    expect(book, isNotNull);
    expect(slowProvider.books, hasLength(1));
  });

  test('importPdf rechaza archivos sin cabecera PDF', () async {
    final junk = File(p.join(tempDir.path, 'fake.pdf'));
    await junk.writeAsBytes(const [0x00, 0x01, 0x02, 0x03]);

    final badProvider = LibraryProvider(
      datasource: datasource,
      importService: PdfImportService(
        datasource,
        picker: () async => PickedPdfFile(
          sourcePath: junk.path,
          displayName: 'fake.pdf',
          fileSize: 4,
        ),
        documentsDirectory: () async => tempDir,
      ),
    );

    final result = await badProvider.importPdf();
    expect(result, isNull);
    expect(badProvider.error, isNotNull);
    expect(badProvider.books, isEmpty);
  });
}
