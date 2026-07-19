import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_downloader/flutter_downloader.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../core/utils/app_paths.dart';
import '../../core/utils/file_name_sanitizer.dart';
import '../../core/utils/pdf_header.dart';
import '../../core/utils/pdf_url_utils.dart';
import '../models/book.dart';
import 'library_local_datasource.dart';

typedef DownloadProgress = void Function(double progress);

/// Cancelación solicitada por el usuario.
class DownloadCancelledException implements Exception {
  const DownloadCancelledException();

  @override
  String toString() => 'DownloadCancelledException';
}

/// Descarga PDFs por URL a `Documents/library` y los registra en la DB.
///
/// En Android/iOS intenta encolar con [FlutterDownloader] (segundo plano);
/// si no está disponible, usa HTTP en streaming a disco (sin cargar todo en RAM).
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

  bool _cancelRequested = false;
  String? _activeNativeTaskId;
  Future<Book>? _activeDownload;

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

  /// Cancela la descarga HTTP/nativa en curso (si hay).
  Future<void> cancelActiveDownload() async {
    _cancelRequested = true;
    final taskId = _activeNativeTaskId;
    if (taskId != null) {
      await _cancelNativeTask(taskId);
    }
  }

  void _throwIfCancelled() {
    if (_cancelRequested) {
      throw const DownloadCancelledException();
    }
  }

  Future<Book> downloadFromUrl(
    String rawUrl, {
    DownloadProgress? onProgress,
    int? collectionId,
  }) async {
    if (_activeDownload != null) {
      throw StateError('Ya hay una descarga en curso');
    }

    final future = _downloadFromUrlLocked(
      rawUrl,
      onProgress: onProgress,
      collectionId: collectionId,
    );
    _activeDownload = future;
    try {
      return await future;
    } finally {
      if (identical(_activeDownload, future)) {
        _activeDownload = null;
      }
    }
  }

  Future<Book> _downloadFromUrlLocked(
    String rawUrl, {
    DownloadProgress? onProgress,
    int? collectionId,
  }) async {
    _cancelRequested = false;
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
      } on DownloadCancelledException {
        rethrow;
      } on TimeoutException {
        // No re-descargar por HTTP tras un timeout nativo (evitar doble costo).
        rethrow;
      } catch (e) {
        _throwIfCancelled();
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
    _throwIfCancelled();
    onProgress?.call(0);

    final libraryDir = await _ensureLibraryDir();
    final fileName = FileNameSanitizer.sanitize(
      PdfUrlUtils.fileNameFromUrl(url),
    );
    final existing = await _existingFileNames(libraryDir);
    final unique = FileNameSanitizer.uniqueName(fileName, existing);
    final destination = p.join(libraryDir.path, unique);
    final tempPath = '$destination.part';
    final tempFile = File(tempPath);
    final destinationFile = File(destination);

    var received = 0;
    IOSink? sink;
    try {
      final request = http.Request('GET', Uri.parse(url));
      request.headers['Accept'] = 'application/pdf,*/*';

      final response = await _http.send(request).timeout(
        const Duration(seconds: 45),
        onTimeout: () {
          throw TimeoutException('Tiempo de espera de conexión agotado');
        },
      );
      _throwIfCancelled();

      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw HttpException(
          'Descarga fallida (${response.statusCode})',
          uri: Uri.parse(url),
        );
      }

      final contentType = response.headers['content-type'] ?? '';
      final total = response.contentLength ?? 0;

      sink = tempFile.openWrite();
      await for (final chunk in response.stream.timeout(
        const Duration(seconds: 60),
        onTimeout: (sink) {
          sink.addError(
            TimeoutException('Tiempo de espera de descarga agotado'),
          );
          sink.close();
        },
      )) {
        _throwIfCancelled();
        sink.add(chunk);
        received += chunk.length;
        if (total > 0) {
          onProgress?.call((received / total).clamp(0.0, 1.0));
        }
      }
      await sink.flush();
      await sink.close();
      sink = null;

      _throwIfCancelled();
      await PdfHeader.assertFile(
        tempFile,
        contentType: contentType,
        invalidMessage: 'La URL no devolvió un PDF válido',
      );
      await tempFile.rename(destination);
      onProgress?.call(1);

      final title = p.basenameWithoutExtension(unique).replaceAll('_', ' ');
      final size = await destinationFile.length();
      return await _datasource.insertBook(
        Book(
          title: title,
          filePath: destination,
          fileSize: size,
          addedAt: DateTime.now(),
          collectionId: collectionId,
        ),
      );
    } on DownloadCancelledException {
      await sink?.close();
      await _deleteQuietly(tempFile);
      await _deleteQuietly(destinationFile);
      rethrow;
    } catch (e) {
      await sink?.close();
      await _deleteQuietly(tempFile);
      await _deleteQuietly(destinationFile);
      if (_cancelRequested) {
        throw const DownloadCancelledException();
      }
      rethrow;
    }
  }

  Future<Book> _downloadWithFlutterDownloader(
    String url, {
    DownloadProgress? onProgress,
    int? collectionId,
  }) async {
    await ensureNativeInitialized();
    _throwIfCancelled();

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

    _activeNativeTaskId = taskId;
    try {
      _throwIfCancelled();
      final path = await _waitForNativeTask(
        taskId,
        expectedPath: p.join(tempDir.path, fileName),
        onProgress: onProgress,
      );

      final source = File(path);
      await PdfHeader.assertFile(source);
      return await _persistFile(
        source: source,
        fileName: fileName,
        collectionId: collectionId,
      );
    } catch (e) {
      await _cancelNativeTask(taskId);
      if (_cancelRequested) {
        throw const DownloadCancelledException();
      }
      rethrow;
    } finally {
      if (_activeNativeTaskId == taskId) {
        _activeNativeTaskId = null;
      }
    }
  }

  Future<void> _cancelNativeTask(String taskId) async {
    try {
      await FlutterDownloader.cancel(taskId: taskId);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('FlutterDownloader.cancel: $e');
      }
    }
  }

  Future<String> _waitForNativeTask(
    String taskId, {
    required String expectedPath,
    DownloadProgress? onProgress,
  }) async {
    const timeout = Duration(minutes: 3);
    final started = DateTime.now();

    while (DateTime.now().difference(started) < timeout) {
      _throwIfCancelled();

      // Evita SQL crudo con interpolación; filtra en cliente.
      final tasks = await FlutterDownloader.loadTasks();
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
        if (task.status == DownloadTaskStatus.failed) {
          throw StateError('Descarga nativa fallida');
        }
        if (task.status == DownloadTaskStatus.canceled) {
          throw const DownloadCancelledException();
        }
      }

      await Future<void>.delayed(const Duration(milliseconds: 300));
    }

    throw TimeoutException('Tiempo de espera de descarga agotado');
  }

  Future<Book> _persistFile({
    required File source,
    required String fileName,
    int? collectionId,
  }) async {
    final libraryDir = await _ensureLibraryDir();
    final existing = await _existingFileNames(libraryDir);
    final unique = FileNameSanitizer.uniqueName(fileName, existing);
    final destination = p.join(libraryDir.path, unique);
    final destinationFile = File(destination);

    await source.copy(destination);
    try {
      await source.delete();
    } catch (_) {
      // El temporal nativo puede quedar; no es crítico.
    }

    try {
      final title = p.basenameWithoutExtension(unique).replaceAll('_', ' ');
      final size = await destinationFile.length();
      return await _datasource.insertBook(
        Book(
          title: title,
          filePath: destination,
          fileSize: size,
          addedAt: DateTime.now(),
          collectionId: collectionId,
        ),
      );
    } catch (e) {
      await _deleteQuietly(destinationFile);
      rethrow;
    }
  }

  Future<Directory> _ensureLibraryDir() async {
    final docs = await _documentsDirectory();
    final libraryDir = Directory(p.join(docs.path, 'library'));
    if (!await libraryDir.exists()) {
      await libraryDir.create(recursive: true);
    }
    return libraryDir;
  }

  Future<Set<String>> _existingFileNames(Directory libraryDir) async {
    return libraryDir
        .list()
        .where((entity) => entity is File)
        .map((entity) => p.basename(entity.path).toLowerCase())
        .toSet();
  }

  Future<void> _deleteQuietly(File file) async {
    try {
      if (await file.exists()) {
        await file.delete();
      }
    } catch (_) {
      // Limpieza best-effort.
    }
  }

  void dispose() {
    _cancelRequested = true;
    _http.close();
  }
}
