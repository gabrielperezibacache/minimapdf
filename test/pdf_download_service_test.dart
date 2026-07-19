import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:minimal_pdf/core/database/app_database.dart';
import 'package:minimal_pdf/core/database/library_database.dart';
import 'package:minimal_pdf/data/datasources/library_local_datasource.dart';
import 'package:minimal_pdf/data/datasources/pdf_download_service.dart';
import 'package:minimal_pdf/data/models/book.dart';
import 'package:minimal_pdf/data/models/collection.dart';
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

  test('capturePdf no descarga HTML genérico de la página actual', () async {
    final service = PdfDownloadService(
      datasource,
      httpClient: MockClient((request) async {
        fail('No debería descargar: ${request.url}');
      }),
      documentsDirectory: () async => tempDir,
      useFlutterDownloader: false,
    );
    final provider = DownloaderProvider(service);

    final book = await provider.capturePdf(
      currentUrl: 'https://cdn.example.com/article.html',
    );
    expect(book, isNull);
    expect(provider.error, 'noPdfLink');
    service.dispose();
  });

  test('capturePdf con varios PDFs no elige uno al azar', () async {
    final service = PdfDownloadService(
      datasource,
      httpClient: MockClient((request) async {
        fail('No debería descargar: ${request.url}');
      }),
      documentsDirectory: () async => tempDir,
      useFlutterDownloader: false,
    );
    final provider = DownloaderProvider(service);
    provider.setDetectedPdfUrls([
      'https://cdn.example.com/a.pdf',
      'https://cdn.example.com/b.pdf',
    ]);

    final book = await provider.capturePdf();
    expect(book, isNull);
    expect(provider.error, 'multiplePdfsDetected');
    expect(provider.messageArg, '2');
    expect(provider.detectedPdfUrls.length, 2);
    service.dispose();
  });

  test('DownloaderProvider mapea timeout a mensaje claro', () async {
    final service = PdfDownloadService(
      datasource,
      httpClient: MockClient((request) async {
        throw TimeoutException('slow');
      }),
      documentsDirectory: () async => tempDir,
      useFlutterDownloader: false,
    );
    final provider = DownloaderProvider(service);
    final book = await provider.downloadUrl('https://example.com/slow.pdf');
    expect(book, isNull);
    expect(provider.error, 'timeout');
    service.dispose();
  });

  test('download evita UNIQUE de fila huérfana con mismo basename', () async {
    final libraryDir = Directory(p.join(tempDir.path, 'library'));
    await libraryDir.create(recursive: true);
    final ghostPath = p.join(libraryDir.path, 'guide.pdf');
    await datasource.insertBook(
      Book(
        title: 'Ghost',
        filePath: ghostPath,
        fileSize: 1,
        addedAt: DateTime(2026, 7, 1),
      ),
    );

    final client = MockClient((request) async {
      return http.Response.bytes(
        const [0x25, 0x50, 0x44, 0x46, 0x2D, 0x31],
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
    expect(book.filePath, isNot(equals(ghostPath)));
    expect(p.basename(book.filePath).toLowerCase(), contains('guide'));
    expect(File(book.filePath).existsSync(), isTrue);
    service.dispose();
  });

  test('resolveCaptureCandidates agrupa URL actual y detectados', () {
    final service = PdfDownloadService(
      datasource,
      httpClient: MockClient((_) async => http.Response('', 404)),
      documentsDirectory: () async => tempDir,
      useFlutterDownloader: false,
    );
    final provider = DownloaderProvider(service)
      ..setDetectedPdfUrls([
        'https://cdn.example.com/a.pdf',
        'https://cdn.example.com/b.pdf',
      ]);

    final candidates = provider.resolveCaptureCandidates(
      currentUrl: 'https://cdn.example.com/a.pdf',
    );
    expect(candidates.length, 2);
    service.dispose();
  });

  test('downloadFromUrl respeta collectionId activo', () async {
    final collection = await datasource.insertCollection(
      Collection(name: 'Descargas', createdAt: DateTime(2026, 7, 1)),
    );

    final client = MockClient((request) async {
      return http.Response.bytes(
        const [0x25, 0x50, 0x44, 0x46, 0x2D, 0x31],
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
    final provider = DownloaderProvider(service)
      ..setTargetCollectionId(collection.id);

    final book = await provider.downloadUrl('https://example.com/doc.pdf');
    expect(book, isNotNull);
    expect(book!.collectionId, collection.id);
    service.dispose();
  });

  test('downloadFromUrl limpia archivo si no es PDF', () async {
    final client = MockClient((request) async {
      return http.Response.bytes(
        const [0x00, 0x01, 0x02, 0x03],
        200,
        headers: {'content-type': 'text/plain'},
      );
    });

    final service = PdfDownloadService(
      datasource,
      httpClient: client,
      documentsDirectory: () async => tempDir,
      useFlutterDownloader: false,
    );

    await expectLater(
      service.downloadFromUrl('https://example.com/not-a-pdf.pdf'),
      throwsA(isA<FormatException>()),
    );

    final libraryDir = Directory(p.join(tempDir.path, 'library'));
    if (await libraryDir.exists()) {
      final leftovers = await libraryDir.list().toList();
      expect(leftovers, isEmpty);
    }
    service.dispose();
  });

  test('segunda descarga concurrente se rechaza', () async {
    final client = MockClient((request) async {
      await Future<void>.delayed(const Duration(milliseconds: 60));
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

    final first = provider.downloadUrl('https://example.com/a.pdf');
    await Future<void>.delayed(const Duration(milliseconds: 10));
    final second = await provider.downloadUrl('https://example.com/b.pdf');

    expect(second, isNull);
    expect(provider.error, 'downloadInProgress');
    final book = await first;
    expect(book, isNotNull);
    service.dispose();
  });

  test('colección borrada durante descarga se ignora (sin FK)', () async {
    final collection = await datasource.insertCollection(
      Collection(name: 'Temporal', createdAt: DateTime(2026, 7, 1)),
    );

    final client = MockClient((request) async {
      await Future<void>.delayed(const Duration(milliseconds: 40));
      return http.Response.bytes(
        const [0x25, 0x50, 0x44, 0x46, 0x2D, 0x31],
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

    final download = service.downloadFromUrl(
      'https://example.com/keep.pdf',
      collectionId: collection.id,
    );
    await Future<void>.delayed(const Duration(milliseconds: 10));
    await datasource.removeCollection(collection.id!);

    final book = await download;
    expect(book.collectionId, isNull);
    expect(File(book.filePath).existsSync(), isTrue);
    service.dispose();
  });

  test('cancelActiveDownload corta stream HTTP colgado', () async {
    final client = MockClient.streaming((request, _) async {
      final stream = Stream<List<int>>.periodic(
        const Duration(milliseconds: 200),
        (_) => const [0x25, 0x50, 0x44, 0x46],
      );
      return http.StreamedResponse(
        stream,
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

    final download = service.downloadFromUrl('https://example.com/hang.pdf');
    await Future<void>.delayed(const Duration(milliseconds: 30));
    await service.cancelActiveDownload();

    await expectLater(download, throwsA(isA<DownloadCancelledException>()));
    service.dispose();
  });

  test('cancelActiveDownload interrumpe descarga HTTP', () async {
    final client = MockClient((request) async {
      await Future<void>.delayed(const Duration(milliseconds: 80));
      return http.Response.bytes(
        List<int>.filled(256 * 1024, 0x20)
          ..[0] = 0x25
          ..[1] = 0x50
          ..[2] = 0x44
          ..[3] = 0x46,
        200,
        headers: {
          'content-type': 'application/pdf',
          'content-length': '${256 * 1024}',
        },
      );
    });

    final service = PdfDownloadService(
      datasource,
      httpClient: client,
      documentsDirectory: () async => tempDir,
      useFlutterDownloader: false,
    );
    final provider = DownloaderProvider(service);

    final download = provider.downloadUrl('https://example.com/slow.pdf');
    await Future<void>.delayed(const Duration(milliseconds: 20));
    await provider.cancelDownload();
    final book = await download;

    expect(book, isNull);
    expect(provider.statusMessage, 'downloadCancelled');
    service.dispose();
  });

  test('dispose completa descarga HTTP en curso sin colgarse', () async {
    final client = _HangingStreamClient();

    final service = PdfDownloadService(
      datasource,
      httpClient: client,
      documentsDirectory: () async => tempDir,
      useFlutterDownloader: false,
    );

    final download = service.downloadFromUrl('https://example.com/hang.pdf');
    await Future<void>.delayed(const Duration(milliseconds: 40));
    service.dispose();

    await expectLater(
      download.timeout(const Duration(seconds: 2)),
      throwsA(isA<DownloadCancelledException>()),
    );
    await client.closeStream();
  });

  test('DownloaderProvider limita notificaciones de progreso', () async {
    var notifyCount = 0;
    final client = MockClient((request) async {
      return http.Response.bytes(
        List<int>.filled(64 * 1024, 0x20)
          ..[0] = 0x25
          ..[1] = 0x50
          ..[2] = 0x44
          ..[3] = 0x46,
        200,
        headers: {
          'content-type': 'application/pdf',
          'content-length': '${64 * 1024}',
        },
      );
    });

    final service = PdfDownloadService(
      datasource,
      httpClient: client,
      documentsDirectory: () async => tempDir,
      useFlutterDownloader: false,
    );
    final provider = DownloaderProvider(
      service,
      progressThrottle: const Duration(milliseconds: 50),
    )..addListener(() => notifyCount++);

    final book = await provider.downloadUrl('https://example.com/big.pdf');
    expect(book, isNotNull);
    // Con throttle no debería notificar una vez por cada chunk pequeño.
    expect(notifyCount, lessThan(40));
    service.dispose();
  });
}

/// Cliente HTTP cuyo body nunca termina (para probar dispose/cancel).
class _HangingStreamClient extends http.BaseClient {
  StreamController<List<int>>? _controller;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final controller = StreamController<List<int>>();
    _controller = controller;
    controller.add(const [0x25, 0x50, 0x44, 0x46]);
    return http.StreamedResponse(
      controller.stream,
      200,
      headers: const {'content-type': 'application/pdf'},
    );
  }

  Future<void> closeStream() async {
    final controller = _controller;
    if (controller != null && !controller.isClosed) {
      await controller.close();
    }
  }
}
