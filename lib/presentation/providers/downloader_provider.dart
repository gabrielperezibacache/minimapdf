import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../../core/utils/pdf_url_utils.dart';
import '../../data/datasources/pdf_download_service.dart';
import '../../data/models/book.dart';
import '../../l10n/app_message_keys.dart';

/// Estado del gestor de descargas y captura desde el mini-navegador.
class DownloaderProvider extends ChangeNotifier {
  DownloaderProvider(
    this.downloadService, {
    this._progressThrottle = const Duration(milliseconds: 120),
  });

  final PdfDownloadService downloadService;
  final Duration _progressThrottle;

  String _urlInput = '';
  String _browserUrl = 'https://www.google.com/search?q=filetype:pdf';
  List<String> _detectedPdfUrls = const [];
  bool _downloading = false;
  double _progress = 0;
  String? _error;
  String? _statusMessage;
  String? _messageArg;
  Book? _lastDownloaded;
  int? _targetCollectionId;
  DateTime? _lastProgressNotify;

  String get urlInput => _urlInput;
  String get browserUrl => _browserUrl;
  List<String> get detectedPdfUrls => _detectedPdfUrls;
  bool get downloading => _downloading;
  double get progress => _progress;
  String? get error => _error;
  String? get statusMessage => _statusMessage;
  String? get messageArg => _messageArg;
  Book? get lastDownloaded => _lastDownloaded;
  bool get hasDetectedPdfs => _detectedPdfUrls.isNotEmpty;
  int? get targetCollectionId => _targetCollectionId;

  void setUrlInput(String value) {
    _urlInput = value;
    notifyListeners();
  }

  void setBrowserUrl(String value) {
    _browserUrl = value;
    notifyListeners();
  }

  /// Colección activa de la biblioteca donde se registrará la descarga.
  void setTargetCollectionId(int? collectionId) {
    _targetCollectionId = collectionId;
  }

  void setDetectedPdfUrls(List<String> urls) {
    final unique = <String>{};
    for (final url in urls) {
      final normalized = PdfUrlUtils.normalizeUrl(url);
      if (PdfUrlUtils.isValidHttpUrl(normalized) &&
          PdfUrlUtils.looksLikePdfUrl(normalized)) {
        unique.add(normalized);
      }
    }
    _detectedPdfUrls = unique.toList(growable: false);
    notifyListeners();
  }

  void clearError() {
    if (_error == null && _messageArg == null) return;
    _error = null;
    _messageArg = null;
    notifyListeners();
  }

  void _reportProgress(double value) {
    _progress = value;
    final now = DateTime.now();
    final last = _lastProgressNotify;
    if (last == null ||
        now.difference(last) >= _progressThrottle ||
        value >= 1.0 ||
        value <= 0.0) {
      _lastProgressNotify = now;
      notifyListeners();
    }
  }

  String _mapDownloadError(Object e) {
    if (e is DownloadCancelledException) {
      return '';
    }
    if (e is FormatException) {
      return e.message;
    }
    if (e is TimeoutException) {
      return AppMessageKeys.timeout;
    }
    if (e is SocketException) {
      return AppMessageKeys.noNetwork;
    }
    if (e is http.ClientException) {
      return AppMessageKeys.connectionFailed;
    }
    if (e is HttpException) {
      return e.message;
    }
    if (e is ArgumentError) {
      return AppMessageKeys.invalidUrl;
    }
    if (e is StateError) {
      final msg = e.message;
      if (msg.contains('en curso') || msg.contains('Ya hay una descarga')) {
        return AppMessageKeys.downloadInProgress;
      }
      if (msg.contains('nativa fallida') || msg.contains('archivo no existe')) {
        return AppMessageKeys.nativeDownloadFailed;
      }
      return msg;
    }
    return AppMessageKeys.downloadFailed;
  }

  Future<Book?> downloadUrl(String rawUrl) async {
    final url = PdfUrlUtils.normalizeUrl(rawUrl);
    if (!PdfUrlUtils.isValidHttpUrl(url)) {
      _error = AppMessageKeys.invalidUrl;
      _messageArg = null;
      notifyListeners();
      return null;
    }

    if (_downloading) {
      _error = AppMessageKeys.downloadInProgress;
      _messageArg = null;
      notifyListeners();
      return null;
    }

    _downloading = true;
    _progress = 0;
    _error = null;
    _messageArg = null;
    _statusMessage = AppMessageKeys.downloading;
    _lastDownloaded = null;
    _lastProgressNotify = null;
    notifyListeners();

    try {
      final book = await downloadService.downloadFromUrl(
        url,
        onProgress: _reportProgress,
        collectionId: _targetCollectionId,
      );
      _lastDownloaded = book;
      _statusMessage = AppMessageKeys.savedToLibrary;
      _messageArg = book.title;
      return book;
    } on DownloadCancelledException {
      _error = null;
      _statusMessage = AppMessageKeys.downloadCancelled;
      _messageArg = null;
      return null;
    } catch (e) {
      _error = _mapDownloadError(e);
      _statusMessage = null;
      _messageArg = null;
      if (kDebugMode) {
        debugPrint('DownloaderProvider.downloadUrl: $e');
      }
      return null;
    } finally {
      _downloading = false;
      notifyListeners();
    }
  }

  Future<void> cancelDownload() async {
    if (!_downloading) return;
    await downloadService.cancelActiveDownload();
  }

  Future<Book?> downloadFromInput() => downloadUrl(_urlInput);

  /// Candidatos PDF únicos para captura (URL actual + detectados).
  List<String> resolveCaptureCandidates({String? currentUrl}) {
    final candidates = <String>[
      if (currentUrl != null && PdfUrlUtils.looksLikePdfUrl(currentUrl))
        currentUrl,
      ..._detectedPdfUrls,
    ];

    final unique = <String>{};
    for (final url in candidates) {
      final normalized = PdfUrlUtils.normalizeUrl(url);
      if (PdfUrlUtils.looksLikePdfUrl(normalized)) {
        unique.add(normalized);
      }
    }
    return unique.toList(growable: false);
  }

  /// Captura solo URLs que parezcan PDF (nunca HTML genérico).
  ///
  /// Si hay varios candidatos, no elige al azar: pide elegir de la lista.
  Future<Book?> capturePdf({String? currentUrl}) async {
    final unique = resolveCaptureCandidates(currentUrl: currentUrl);

    if (unique.isEmpty) {
      _error = AppMessageKeys.noPdfLink;
      _messageArg = null;
      notifyListeners();
      return null;
    }

    if (unique.length > 1) {
      _detectedPdfUrls = unique;
      _error = AppMessageKeys.multiplePdfsDetected;
      _messageArg = '${unique.length}';
      _statusMessage = null;
      notifyListeners();
      return null;
    }

    return downloadUrl(unique.first);
  }
}
