import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_downloader/flutter_downloader.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../core/utils/app_paths.dart';
import '../../core/utils/file_name_sanitizer.dart';
import '../../core/utils/library_file_coordinator.dart';
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
  StreamSubscription<List<int>>? _httpSubscription;
  Completer<void>? _httpDone;

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
    final done = _httpDone;
    if (done != null && !done.isCompleted) {
      done.completeError(const DownloadCancelledException());
    }
    final subscription = _httpSubscription;
    if (subscription != null) {
      await subscription.cancel();
    }
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

    final stagingDir = await _ensureLibraryDir();
    final fileName = FileNameSanitizer.sanitize(
      PdfUrlUtils.fileNameFromUrl(url),
    );
    // Descarga a un temporal único; el nombre final se reserva al persistir.
    final stagingName =
        '${DateTime.now().microsecondsSinceEpoch}_$fileName.part';
    final tempFile = File(p.join(stagingDir.path, stagingName));

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

      if (_cancelRequested) {
        await _drainQuietly(response.stream);
        throw const DownloadCancelledException();
      }

      if (response.statusCode < 200 || response.statusCode >= 300) {
        await _drainQuietly(response.stream);
        throw HttpException(
          'Descarga fallida (${response.statusCode})',
          uri: Uri.parse(url),
        );
      }

      final contentType = response.headers['content-type'] ?? '';
      final total = response.contentLength ?? 0;

      sink = tempFile.openWrite();
      final done = Completer<void>();
      _httpDone = done;
      final timedStream = response.stream.timeout(
        const Duration(seconds: 60),
        onTimeout: (eventSink) {
          eventSink.addError(
            TimeoutException('Tiempo de espera de descarga agotado'),
          );
          eventSink.close();
        },
      );

      // late: el callback de datos necesita pausar la propia suscripción.
      late final StreamSubscription<List<int>> subscription;
      subscription = timedStream.listen(
        (chunk) {
          if (_cancelRequested) {
            if (!done.isCompleted) {
              done.completeError(const DownloadCancelledException());
            }
            return;
          }
          // Backpressure: pausa el stream mientras se escribe a disco.
          subscription.pause();
          () async {
            try {
              sink!.add(chunk);
              received += chunk.length;
              if (total > 0) {
                onProgress?.call((received / total).clamp(0.0, 1.0));
              }
              // Cede el event loop para vaciar el buffer del IOSink.
              await Future<void>.delayed(Duration.zero);
            } catch (e, st) {
              if (!done.isCompleted) {
                done.completeError(e, st);
              }
            } finally {
              if (!done.isCompleted) {
                subscription.resume();
              }
            }
          }();
        },
        onError: (Object e, StackTrace st) {
          if (done.isCompleted) return;
          if (_cancelRequested) {
            done.completeError(const DownloadCancelledException());
          } else {
            done.completeError(e, st);
          }
        },
        onDone: () {
          if (done.isCompleted) return;
          if (_cancelRequested) {
            done.completeError(const DownloadCancelledException());
          } else {
            done.complete();
          }
        },
        cancelOnError: true,
      );
      _httpSubscription = subscription;

      try {
        await done.future;
      } finally {
        if (identical(_httpDone, done)) {
          _httpDone = null;
        }
        await subscription.cancel();
        if (identical(_httpSubscription, subscription)) {
          _httpSubscription = null;
        }
      }

      await sink.flush();
      await sink.close();
      sink = null;

      _throwIfCancelled();
      // Content-Length no es fiable con content-encoding (p. ej. gzip):
      // package:http puede entregar bytes ya descomprimidos.
      final encoding =
          (response.headers['content-encoding'] ?? '').trim().toLowerCase();
      final lengthTrusted =
          encoding.isEmpty || encoding == 'identity' || encoding == 'none';
      if (lengthTrusted && total > 0 && received != total) {
        throw StateError(
          'Descarga incompleta ($received de $total bytes)',
        );
      }
      await PdfHeader.assertFile(
        tempFile,
        contentType: contentType,
        invalidMessage: 'La URL no devolvió un PDF válido',
      );
      onProgress?.call(1);
      _throwIfCancelled();
      return await _persistFile(
        source: tempFile,
        fileName: fileName,
        collectionId: collectionId,
        deleteSource: true,
      );
    } on DownloadCancelledException {
      await sink?.close();
      await _deleteQuietly(tempFile);
      rethrow;
    } catch (e) {
      await sink?.close();
      await _deleteQuietly(tempFile);
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
    // Nombre temporal único: evita colisiones con leftovers de cancel/kill.
    final stagingName =
        '${DateTime.now().microsecondsSinceEpoch}_$fileName';

    final taskId = await FlutterDownloader.enqueue(
      url: url,
      savedDir: tempDir.path,
      fileName: stagingName,
      showNotification: false,
      openFileFromNotification: false,
      requiresStorageNotLow: false,
    );

    if (taskId == null) {
      throw StateError('No se pudo encolar la descarga nativa');
    }

    final expectedPath = p.join(tempDir.path, stagingName);
    _activeNativeTaskId = taskId;
    String? resolvedPath;
    try {
      _throwIfCancelled();
      resolvedPath = await _waitForNativeTask(
        taskId,
        expectedPath: expectedPath,
        onProgress: onProgress,
      );

      final source = File(resolvedPath);
      await PdfHeader.assertFile(source);
      return await _persistFile(
        source: source,
        fileName: fileName,
        collectionId: collectionId,
        deleteSource: true,
      );
    } catch (e) {
      await _cancelNativeTask(taskId);
      await _deleteQuietly(File(expectedPath));
      final extra = resolvedPath;
      if (extra != null && extra != expectedPath) {
        await _deleteQuietly(File(extra));
      }
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
          final resolved = _resolveNativeDownloadPath(
            task: task,
            expectedPath: expectedPath,
          );
          if (resolved != null && await File(resolved).exists()) {
            return resolved;
          }
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

  /// Resuelve la ruta nativa solo si queda dentro de [task.savedDir].
  String? _resolveNativeDownloadPath({
    required DownloadTask task,
    required String expectedPath,
  }) {
    final savedDir = task.savedDir.trim();
    if (savedDir.isEmpty) return expectedPath;
    final root = p.normalize(p.absolute(savedDir));
    final filename = task.filename?.trim();
    if (filename == null || filename.isEmpty) return expectedPath;
    final resolved = p.normalize(p.absolute(p.join(savedDir, filename)));
    if (resolved == root || p.isWithin(root, resolved)) {
      return resolved;
    }
    return expectedPath;
  }

  Future<Book> _persistFile({
    required File source,
    required String fileName,
    int? collectionId,
    bool deleteSource = true,
  }) async {
    return LibraryFileCoordinator.runExclusive(() async {
      _throwIfCancelled();
      final libraryDir = await _ensureLibraryDir();
      await _sweepOrphanPartFiles(libraryDir, keepPath: source.path);
      final onDisk = await _existingFileNames(libraryDir);
      final reserved = await _datasource.listReservedLibraryBasenames();
      final existing = {...onDisk, ...reserved};
      final unique = FileNameSanitizer.uniqueName(fileName, existing);
      final destination = p.join(libraryDir.path, unique);
      final destinationFile = File(destination);

      try {
        _throwIfCancelled();
        if (p.equals(source.path, destination)) {
          // Ya está en destino (raro); no copiar.
        } else if (source.path.endsWith('.part') &&
            p.dirname(source.path) == libraryDir.path) {
          await source.rename(destination);
        } else {
          await source.copy(destination);
          if (deleteSource) {
            await _deleteQuietly(source);
          }
        }

        _throwIfCancelled();
        final title = p.basenameWithoutExtension(unique).replaceAll('_', ' ');
        final size = await destinationFile.length();
        final resolvedCollectionId =
            await _resolveCollectionId(collectionId);
        _throwIfCancelled();
        return await _datasource.insertBook(
          Book(
            title: title,
            filePath: destination,
            fileSize: size,
            addedAt: DateTime.now(),
            collectionId: resolvedCollectionId,
          ),
        );
      } catch (e) {
        await _deleteQuietly(destinationFile);
        rethrow;
      }
    });
  }

  /// Si la colección se borró durante la descarga, evita fallo FK.
  Future<int?> _resolveCollectionId(int? collectionId) async {
    if (collectionId == null) return null;
    final found = await _datasource.findCollectionById(collectionId);
    return found?.id;
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
    final names = <String>{};
    await for (final entity in libraryDir.list()) {
      if (entity is! File) continue;
      final base = p.basename(entity.path).toLowerCase();
      if (base.endsWith('.part')) continue;
      names.add(base);
    }
    return names;
  }

  Future<void> _sweepOrphanPartFiles(
    Directory libraryDir, {
    String? keepPath,
  }) async {
    try {
      await for (final entity in libraryDir.list()) {
        if (entity is! File) continue;
        if (!entity.path.toLowerCase().endsWith('.part')) continue;
        if (keepPath != null && p.equals(entity.path, keepPath)) continue;
        await _deleteQuietly(entity);
      }
    } catch (_) {
      // Limpieza best-effort.
    }
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

  Future<void> _drainQuietly(Stream<List<int>> stream) async {
    try {
      await stream.drain<void>();
    } catch (_) {
      // Best-effort: liberar la conexión HTTP.
    }
  }

  void dispose() {
    // Misma ruta que cancelActiveDownload: completa _httpDone para no
    // dejar colgado el await de la descarga en curso.
    _cancelRequested = true;
    final done = _httpDone;
    if (done != null && !done.isCompleted) {
      done.completeError(const DownloadCancelledException());
    }
    final subscription = _httpSubscription;
    if (subscription != null) {
      unawaited(subscription.cancel());
      _httpSubscription = null;
    }
    final taskId = _activeNativeTaskId;
    if (taskId != null) {
      unawaited(_cancelNativeTask(taskId));
    }
    _http.close();
  }
}
