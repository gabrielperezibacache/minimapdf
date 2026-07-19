import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:minimal_pdf/core/database/app_database.dart';
import 'package:minimal_pdf/core/database/library_database.dart';
import 'package:minimal_pdf/data/datasources/library_local_datasource.dart';
import 'package:minimal_pdf/data/datasources/pdf_download_service.dart';
import 'package:minimal_pdf/presentation/providers/downloader_provider.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late AppDatabase appDatabase;
  late LibraryLocalDatasource datasource;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('minimal_pdf_dl_');
    appDatabase = AppDatabase(
      customFactory: databaseFactoryFfi,
      databasePath: p.join(tempDir.path, 'library.db'),
    );
    await appDatabase.open();
    datasource = LibraryLocalDatasource(LibraryDatabase(appDatabase));
  });

  tearDown(() async {
    await appDatabase.close();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('downloadFromUrl guarda PDF en library y registra Book', () async {
    final client = MockClient((request) async {
      expect(request.url.toString(), 'https://example.com/guide.pdf');
      return http.Response.bytes(
        const [0x25, 0x50, 0x44, 0x46, 0x2D, 0x31], // %PDF-1
        200,
        headers: {'content-type': 'application/pdf'},
      );
    });

    final service = PdfDownloadService(
      datasource,
      httpClient: client,
      documentsDirectory: () async => tempDir,
      useFlutterDownloader: false,
    );

    final book = await service.downloadFromUrl('https://example.com/guide.pdf');
    expect(book.title.toLowerCase(), contains('guide'));
    expect(File(book.filePath).existsSync(), isTrue);
    expect(book.filePath, contains('${p.separator}library${p.separator}'));
    service.dispose();
  });

  test('DownloaderProvider.capturePdf usa enlace detectado', () async {
    final client = MockClient((request) async {
      return http.Response.bytes(
        const [0x25, 0x50, 0x44, 0x46],
        200,
        headers: {'content-type': 'application/pdf'},
      );
    });

    final service = PdfDownloadService(
      datasource,
      httpClient: client,
      documentsDirectory: () async => tempDir,
      useFlutterDownloader: false,
    );
    final provider = DownloaderProvider(service);
    provider.setDetectedPdfUrls(['https://cdn.example.com/paper.pdf']);

    final book = await provider.capturePdf(
      currentUrl: 'https://cdn.example.com/article',
    );
    expect(book, isNotNull);
    expect(book!.filePath, contains('paper'));
    service.dispose();
  });
}
