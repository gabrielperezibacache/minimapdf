import 'package:flutter/foundation.dart';

import '../../core/utils/pdf_url_utils.dart';
import '../../data/datasources/pdf_download_service.dart';
import '../../data/models/book.dart';
import '../../l10n/app_message_keys.dart';

/// Estado del gestor de descargas y captura desde el mini-navegador.
class DownloaderProvider extends ChangeNotifier {
  DownloaderProvider(this.downloadService);

  final PdfDownloadService downloadService;

  String _urlInput = '';
  String _browserUrl = 'https://www.google.com/search?q=filetype:pdf';
  List<String> _detectedPdfUrls = const [];
  bool _downloading = false;
  double _progress = 0;
  String? _error;
  String? _statusMessageKey;
  String? _statusMessageArg;
  Book? _lastDownloaded;

  String get urlInput => _urlInput;
  String get browserUrl => _browserUrl;
  List<String> get detectedPdfUrls => _detectedPdfUrls;
  bool get downloading => _downloading;
  double get progress => _progress;
  String? get error => _error;
  String? get statusMessageKey => _statusMessageKey;
  String? get statusMessageArg => _statusMessageArg;
  Book? get lastDownloaded => _lastDownloaded;
  bool get hasDetectedPdfs => _detectedPdfUrls.isNotEmpty;

  void setUrlInput(String value) {
    _urlInput = value;
    notifyListeners();
  }

  void setBrowserUrl(String value) {
    _browserUrl = value;
    notifyListeners();
  }

  void setDetectedPdfUrls(List<String> urls) {
    final unique = <String>{};
    for (final url in urls) {
      final normalized = PdfUrlUtils.normalizeUrl(url);
      if (PdfUrlUtils.isValidHttpUrl(normalized)) {
        unique.add(normalized);
      }
    }
    _detectedPdfUrls = unique.toList(growable: false);
    notifyListeners();
  }

  Future<Book?> downloadUrl(String rawUrl) async {
    final url = PdfUrlUtils.normalizeUrl(rawUrl);
    if (!PdfUrlUtils.isValidHttpUrl(url)) {
      _error = AppMessageKeys.invalidUrl;
      notifyListeners();
      return null;
    }

    _downloading = true;
    _progress = 0;
    _error = null;
    _statusMessageKey = AppMessageKeys.downloading;
    _statusMessageArg = null;
    _lastDownloaded = null;
    notifyListeners();

    try {
      final book = await downloadService.downloadFromUrl(
        url,
        onProgress: (value) {
          _progress = value;
          notifyListeners();
        },
      );
      _lastDownloaded = book;
      _statusMessageKey = AppMessageKeys.savedToLibrary;
      _statusMessageArg = book.title;
      return book;
    } catch (e) {
      _error = AppMessageKeys.downloadFailed;
      _statusMessageKey = null;
      _statusMessageArg = null;
      if (kDebugMode) {
        debugPrint('DownloaderProvider.downloadUrl: $e');
      }
      return null;
    } finally {
      _downloading = false;
      notifyListeners();
    }
  }

  Future<Book?> downloadFromInput() => downloadUrl(_urlInput);

  /// Captura: prioriza URL actual si es PDF; si no, el primer enlace detectado.
  Future<Book?> capturePdf({String? currentUrl}) async {
    final candidates = <String>[
      if (currentUrl != null && PdfUrlUtils.looksLikePdfUrl(currentUrl))
        currentUrl,
      ..._detectedPdfUrls,
      if (currentUrl != null && PdfUrlUtils.isValidHttpUrl(currentUrl))
        currentUrl,
    ];

    if (candidates.isEmpty) {
      _error = AppMessageKeys.noPdfLink;
      notifyListeners();
      return null;
    }

    // Preferir candidatos que parezcan PDF.
    final preferred = candidates.firstWhere(
      PdfUrlUtils.looksLikePdfUrl,
      orElse: () => candidates.first,
    );
    return downloadUrl(preferred);
  }
}
