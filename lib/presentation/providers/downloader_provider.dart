import 'package:flutter/foundation.dart';

import '../../core/utils/pdf_url_utils.dart';
import '../../data/datasources/pdf_download_service.dart';
import '../../data/models/book.dart';

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
    if (_error == null) return;
    _error = null;
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

  Future<Book?> downloadUrl(String rawUrl) async {
    final url = PdfUrlUtils.normalizeUrl(rawUrl);
    if (!PdfUrlUtils.isValidHttpUrl(url)) {
      _error = 'Introduce una URL http(s) válida.';
      notifyListeners();
      return null;
    }

    _downloading = true;
    _progress = 0;
    _error = null;
    _statusMessage = 'Descargando…';
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
      _statusMessage = 'Guardado en biblioteca: ${book.title}';
      return book;
    } on DownloadCancelledException {
      _error = null;
      _statusMessage = 'Descarga cancelada.';
      return null;
    } catch (e) {
      if (e is FormatException) {
        _error = e.message;
      } else {
        _error = 'No se pudo descargar el PDF.';
      }
      _statusMessage = null;
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

  /// Captura solo URLs que parezcan PDF (nunca HTML genérico).
  Future<Book?> capturePdf({String? currentUrl}) async {
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

    if (unique.isEmpty) {
      _error = 'No se encontró un enlace PDF en esta página.';
      notifyListeners();
      return null;
    }

    return downloadUrl(unique.first);
  }
}
