import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter_downloader/flutter_downloader.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../core/utils/app_paths.dart';
import '../../core/utils/file_name_sanitizer.dart';
import '../../core/utils/pdf_url_utils.dart';
import '../models/book.dart';
import 'library_local_datasource.dart';

typedef DownloadProgress = void Function(double progress);

/// Descarga PDFs por URL a `Documents/library` y los registra en la DB.
///
/// En Android/iOS intenta encolar con [FlutterDownloader] (segundo plano);
/// si no está disponible, usa HTTP asíncrono sin bloquear la UI.
class PdfDownloadService {
  PdfDownloadService(
    this._datasource, {
    http.Client? httpClient,
    Future<Directory> Function()? documentsDirectory,
    bool? useFlutterDownloader,
  })  : _http = httpClient ?? http.Client(),
        _documentsDirectory =
            documentsDirectory ?? AppPaths.documentsDirectory,
        _useFlutterDownloader = useFlutterDownloader ?? _defaultNativeFlag;

  final LibraryLocalDatasource _datasource;
  final http.Client _http;
  final Future<Directory> Function() _documentsDirectory;
  final bool _useFlutterDownloader;

  static bool get _defaultNativeFlag {
    if (kIsWeb) return false;
    return defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS;
  }

  /// Inicializa el plugin nativo (seguro llamar varias veces).
  static Future<void> ensureNativeInitialized() async {
    if (kIsWeb) return;
    if (defaultTargetPlatform != TargetPlatform.android &&
        defaultTargetPlatform != TargetPlatform.iOS) {
      return;
    }
    try {
      await FlutterDownloader.initialize(debug: kDebugMode, ignoreSsl: false);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('FlutterDownloader.initialize: $e');
      }
    }
  }

  Future<Book> downloadFromUrl(
    String rawUrl, {
    DownloadProgress? onProgress,
    int? collectionId,
  }) async {
    final url = PdfUrlUtils.normalizeUrl(rawUrl);
    if (!PdfUrlUtils.isValidHttpUrl(url)) {
      throw ArgumentError('URL inválida: $rawUrl');
    }

    if (_useFlutterDownloader) {
      try {
        return await _downloadWithFlutterDownloader(
          url,
          onProgress: onProgress,
          collectionId: collectionId,
        );
      } catch (e) {
        if (kDebugMode) {
          debugPrint('Native downloader falló, usando HTTP: $e');
        }
      }
    }

    return _downloadWithHttp(
      url,
      onProgress: onProgress,
      collectionId: collectionId,
    );
  }

  Future<Book> _downloadWithHttp(
    String url, {
    DownloadProgress? onProgress,
    int? collectionId,
  }) async {
    onProgress?.call(0);
    final request = http.Request('GET', Uri.parse(url));
    request.headers['Accept'] = 'application/pdf,*/*';

    final response = await _http.send(request);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw HttpException(
        'Descarga fallida (${response.statusCode})',
        uri: Uri.parse(url),
      );
    }

    final contentType = response.headers['content-type'] ?? '';
    final total = response.contentLength ?? 0;
    final builder = BytesBuilder(copy: false);
    var received = 0;

    await for (final chunk in response.stream) {
      builder.add(chunk);
      received += chunk.length;
      if (total > 0) {
        onProgress?.call((received / total).clamp(0.0, 1.0));
      }
    }

    final bytes = builder.takeBytes();
    _assertPdfBytes(bytes, contentType: contentType);
    onProgress?.call(1);

    final fileName = FileNameSanitizer.sanitize(
      PdfUrlUtils.fileNameFromUrl(url),
    );
    return _persistBytes(
      bytes: bytes,
      fileName: fileName,
      collectionId: collectionId,
    );
  }

  Future<Book> _downloadWithFlutterDownloader(
    String url, {
    DownloadProgress? onProgress,
    int? collectionId,
  }) async {
    await ensureNativeInitialized();

    final tempRoot = await getTemporaryDirectory();
    final tempDir = Directory(p.join(tempRoot.path, 'pdf_downloads'));
    if (!await tempDir.exists()) {
      await tempDir.create(recursive: true);
    }

    final fileName = FileNameSanitizer.sanitize(
      PdfUrlUtils.fileNameFromUrl(url),
    );

    final taskId = await FlutterDownloader.enqueue(
      url: url,
      savedDir: tempDir.path,
      fileName: fileName,
      showNotification: false,
      openFileFromNotification: false,
      requiresStorageNotLow: false,
    );

    if (taskId == null) {
      throw StateError('No se pudo encolar la descarga nativa');
    }

    final path = await _waitForNativeTask(
      taskId,
      expectedPath: p.join(tempDir.path, fileName),
      onProgress: onProgress,
    );

    final bytes = await File(path).readAsBytes();
    _assertPdfBytes(bytes);
    return _persistBytes(
      bytes: bytes,
      fileName: fileName,
      collectionId: collectionId,
    );
  }

  Future<String> _waitForNativeTask(
    String taskId, {
    required String expectedPath,
    DownloadProgress? onProgress,
  }) async {
    const timeout = Duration(minutes: 3);
    final started = DateTime.now();

    while (DateTime.now().difference(started) < timeout) {
      final tasks = await FlutterDownloader.loadTasksWithRawQuery(
        query: "SELECT * FROM task WHERE task_id='$taskId'",
      );
      DownloadTask? task;
      if (tasks != null) {
        for (final item in tasks) {
          if (item.taskId == taskId) {
            task = item;
            break;
          }
        }
      }

      if (task != null) {
        onProgress?.call((task.progress / 100).clamp(0.0, 1.0));
        if (task.status == DownloadTaskStatus.complete) {
          final resolved = task.filename != null
              ? p.join(task.savedDir, task.filename!)
              : expectedPath;
          if (await File(resolved).exists()) return resolved;
          if (await File(expectedPath).exists()) return expectedPath;
          throw StateError('Descarga completa pero el archivo no existe');
        }
        if (task.status == DownloadTaskStatus.failed ||
            task.status == DownloadTaskStatus.canceled) {
          throw StateError('Descarga nativa ${task.status}');
        }
      }

      await Future<void>.delayed(const Duration(milliseconds: 300));
    }

    throw TimeoutException('Tiempo de espera de descarga agotado');
  }

  Future<Book> _persistBytes({
    required Uint8List bytes,
    required String fileName,
    int? collectionId,
  }) async {
    final docs = await _documentsDirectory();
    final libraryDir = Directory(p.join(docs.path, 'library'));
    if (!await libraryDir.exists()) {
      await libraryDir.create(recursive: true);
    }

    final existing = await libraryDir
        .list()
        .where((entity) => entity is File)
        .map((entity) => p.basename(entity.path).toLowerCase())
        .toSet();

    final unique = FileNameSanitizer.uniqueName(fileName, existing);
    final destination = p.join(libraryDir.path, unique);
    await File(destination).writeAsBytes(bytes, flush: true);

    final title = p.basenameWithoutExtension(unique).replaceAll('_', ' ');
    return _datasource.insertBook(
      Book(
        title: title,
        filePath: destination,
        fileSize: bytes.length,
        addedAt: DateTime.now(),
        collectionId: collectionId,
      ),
    );
  }

  void _assertPdfBytes(Uint8List bytes, {String contentType = ''}) {
    if (bytes.isEmpty) {
      throw const FormatException('PDF vacío');
    }

    final isPdfHeader = bytes.length >= 4 &&
        bytes[0] == 0x25 &&
        bytes[1] == 0x50 &&
        bytes[2] == 0x44 &&
        bytes[3] == 0x46;

    if (isPdfHeader) return;
    if (contentType.toLowerCase().contains('pdf')) return;

    throw const FormatException('La URL no devolvió un PDF válido');
  }

  void dispose() {
    _http.close();
  }
}
