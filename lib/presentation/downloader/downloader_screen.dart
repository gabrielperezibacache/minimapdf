import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/pdf_url_utils.dart';
import '../../l10n/app_localizations.dart';
import '../providers/downloader_provider.dart';
import '../providers/library_provider.dart';
import 'pdf_link_detector.dart';

/// Gestor de descargas por URL + mini-navegador con captura de PDF.
class DownloaderScreen extends StatefulWidget {
  const DownloaderScreen({super.key});

  @override
  State<DownloaderScreen> createState() => _DownloaderScreenState();
}

class _DownloaderScreenState extends State<DownloaderScreen> {
  final _urlController = TextEditingController();
  final _browserUrlController = TextEditingController();
  InAppWebViewController? _webController;
  PullToRefreshController? _pullToRefreshController;
  double _pageProgress = 0;
  bool _pullToRefreshReady = false;
  bool _browserReady = false;
  int _scanGeneration = 0;

  /// WebView embebido soportado principalmente en Android/iOS.
  bool get _supportsEmbeddedBrowser {
    if (kIsWeb) return false;
    try {
      return Platform.isAndroid || Platform.isIOS;
    } catch (_) {
      return false;
    }
  }

  static final _privacySettings = InAppWebViewSettings(
    javaScriptEnabled: true,
    domStorageEnabled: false,
    thirdPartyCookiesEnabled: false,
    sharedCookiesEnabled: false,
    mediaPlaybackRequiresUserGesture: true,
    transparentBackground: false,
    useShouldOverrideUrlLoading: true,
    // Requerido para que onDownloadStarting se dispare (Content-Disposition).
    useOnDownloadStart: true,
    javaScriptCanOpenWindowsAutomatically: false,
    supportZoom: true,
    userAgent:
        'MinimalPDF/1.0 (Privacy Browser; no-telemetry; Flutter InAppWebView)',
  );

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final provider = context.read<DownloaderProvider>();
      _urlController.text = provider.urlInput;
      _browserUrlController.text = provider.browserUrl;

      // Limpia caché antes de montar el WebView (evita carrera con la 1ª carga).
      if (_supportsEmbeddedBrowser) {
        try {
          await InAppWebViewController.clearAllCache(includeDiskFiles: true);
        } catch (_) {
          // Best-effort.
        }
      }
      if (!mounted) return;
      setState(() => _browserReady = true);
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_supportsEmbeddedBrowser || _pullToRefreshReady) return;

    final accent = AppPalette.of(context).accent;
    _pullToRefreshController = PullToRefreshController(
      settings: PullToRefreshSettings(color: accent),
      onRefresh: () async {
        if (defaultTargetPlatform == TargetPlatform.android) {
          await _webController?.reload();
        } else if (defaultTargetPlatform == TargetPlatform.iOS) {
          await _webController?.loadUrl(
            urlRequest: URLRequest(url: await _webController?.getUrl()),
          );
        }
      },
    );
    _pullToRefreshReady = true;
  }

  @override
  void dispose() {
    final web = _webController;
    if (web != null) {
      unawaited(web.stopLoading());
    }
    _webController = null;
    _urlController.dispose();
    _browserUrlController.dispose();
    _pullToRefreshController?.dispose();
    super.dispose();
  }

  Future<void> _downloadDirect() async {
    final provider = context.read<DownloaderProvider>();
    provider.setUrlInput(_urlController.text);
    final book = await provider.downloadFromInput();
    if (!mounted) return;
    await _handleResult(book, provider);
  }

  Future<void> _capturePdf() async {
    final provider = context.read<DownloaderProvider>();
    await _scanPdfLinks();
    if (!mounted) return;
    final current = (await _webController?.getUrl())?.toString();
    final candidates = provider.resolveCaptureCandidates(currentUrl: current);

    if (candidates.isEmpty) {
      await provider.capturePdf(currentUrl: current);
      if (!mounted) return;
      await _handleResult(null, provider);
      return;
    }

    String? chosen = candidates.first;
    if (candidates.length > 1) {
      chosen = await _pickPdfUrl(candidates);
      if (!mounted || chosen == null) return;
    }

    final book = await provider.downloadUrl(chosen);
    if (!mounted) return;
    await _handleResult(book, provider);
  }

  Future<String?> _pickPdfUrl(List<String> urls) async {
    final colors = AppPalette.of(context);
    return showModalBottomSheet<String>(
      context: context,
      backgroundColor: colors.panel,
      builder: (context) {
        return SafeArea(
          child: ListView(
            shrinkWrap: true,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Text(
                  'Elige un PDF',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              for (final url in urls)
                ListTile(
                  leading: Icon(Icons.picture_as_pdf, color: colors.accent),
                  title: Text(
                    Uri.tryParse(url)?.pathSegments.lastOrNull ?? url,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(
                    url,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  onTap: () => Navigator.pop(context, url),
                ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _downloadPdfLink(String href) async {
    final provider = context.read<DownloaderProvider>();
    if (provider.downloading) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ya hay una descarga en curso.')),
      );
      return;
    }
    final book = await provider.downloadUrl(href);
    if (!mounted) return;
    await _handleResult(book, provider);
  }

  Future<void> _cancelDownload() async {
    await context.read<DownloaderProvider>().cancelDownload();
  }

  Future<void> _handleResult(dynamic book, DownloaderProvider provider) async {
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    final l10n = AppLocalizations.of(context);
    final library = context.read<LibraryProvider>();
    if (book != null) {
      await library.load();
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.downloaded(book.title as String))),
      );
    } else if (provider.error != null) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            l10n.message(provider.error!, arg: provider.messageArg),
          ),
        ),
      );
    }
  }

  Future<void> _loadBrowserUrl(String raw) async {
    var value = raw.trim();
    if (value.isEmpty) return;
    if (!value.contains('://')) {
      value = 'https://$value';
    }
    if (!PdfUrlUtils.isValidHttpUrl(value)) return;

    context.read<DownloaderProvider>().setBrowserUrl(value);
    _browserUrlController.text = value;
    await _webController?.loadUrl(
      urlRequest: URLRequest(url: WebUri(value)),
    );
  }

  Future<void> _scanPdfLinks() async {
    final controller = _webController;
    if (controller == null) return;
    final generation = _scanGeneration;

    try {
      final result = await controller.evaluateJavascript(
        source: PdfLinkDetector.scanScript,
      );
      final urls = <String>[];
      if (result is List) {
        for (final item in result) {
          if (item != null) urls.add(item.toString());
        }
      }
      if (!mounted || generation != _scanGeneration) return;
      context.read<DownloaderProvider>().setDetectedPdfUrls(urls);
    } catch (_) {
      // Página sin JS o acceso restringido.
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppPalette.of(context);
    final l10n = AppLocalizations.of(context);
    final downloader = context.watch<DownloaderProvider>();
    final statusOrError = downloader.error ?? downloader.statusMessage;

    return PopScope(
      canPop: !downloader.downloading,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        if (downloader.downloading) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Hay una descarga en curso. Cancélala o espera a que termine.',
              ),
            ),
          );
        }
      },
      child: Scaffold(
      appBar: AppBar(
        title: const Text('Descargas'),
        actions: [
          if (downloader.downloading)
            TextButton(
              onPressed: _cancelDownload,
              child: Text(
                'Cancelar',
                style: TextStyle(color: colors.accent),
              ),
            ),
        ],
      ),
      floatingActionButton: _supportsEmbeddedBrowser
          ? FloatingActionButton.extended(
              onPressed: downloader.downloading ? null : _capturePdf,
              icon: downloader.downloading
                  ? SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: colors.onAccent,
                      ),
                    )
                  : const Icon(Icons.download),
              label: Text(
                downloader.hasDetectedPdfs
                    ? 'Capturar PDF (${downloader.detectedPdfUrls.length})'
                    : 'Capturar PDF',
              ),
            )
          : null,
      body: Column(
        children: [
          _DirectUrlBar(
            controller: _urlController,
            downloading: downloader.downloading,
            progress: downloader.progress,
            onDownload: _downloadDirect,
          ),
          if (statusOrError != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  l10n.message(
                    statusOrError,
                    arg: downloader.messageArg ??
                        downloader.lastDownloaded?.title,
                  ),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colors.accent,
                      ),
                ),
              ),
            ),
          if (downloader.hasDetectedPdfs)
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 140),
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                itemCount: downloader.detectedPdfUrls.length,
                separatorBuilder: (_, _) => const SizedBox(height: 2),
                itemBuilder: (context, index) {
                  final url = downloader.detectedPdfUrls[index];
                  final name =
                      Uri.tryParse(url)?.pathSegments.lastOrNull ?? url;
                  return ListTile(
                    dense: true,
                    leading: Icon(
                      Icons.picture_as_pdf_outlined,
                      color: colors.accent,
                      size: 20,
                    ),
                    title: Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: TextButton(
                      onPressed: downloader.downloading
                          ? null
                          : () => _downloadPdfLink(url),
                      child: const Text('Descargar'),
                    ),
                  );
                },
              ),
            ),
          Divider(height: 1, color: colors.border),
          _BrowserChrome(
            controller: _browserUrlController,
            pageProgress: _pageProgress,
            detectedCount: downloader.detectedPdfUrls.length,
            onSubmit: _loadBrowserUrl,
            onBack: () => _webController?.goBack(),
            onForward: () => _webController?.goForward(),
            onReload: () => _webController?.reload(),
          ),
          Expanded(
            child: DecoratedBox(
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(color: colors.border, width: 1),
                ),
              ),
              child: !_supportsEmbeddedBrowser
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          'El mini-navegador está disponible en Android e iOS.\n'
                          'En escritorio puedes usar la URL directa de arriba.',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ),
                    )
                  : !_browserReady
                      ? const Center(child: CircularProgressIndicator())
                      : InAppWebView(
                      key: const ValueKey('minimal-pdf-browser'),
                      initialUrlRequest: URLRequest(
                        url: WebUri(downloader.browserUrl),
                      ),
                      initialSettings: _privacySettings,
                      pullToRefreshController: _pullToRefreshController,
                      onWebViewCreated: (controller) {
                        // La caché ya se limpió en initState antes de montar;
                        // no volver a clearAllCache aquí (carrera con la 1ª carga).
                        _webController = controller;
                      },
                      onLoadStart: (controller, url) {
                        if (!mounted) return;
                        _scanGeneration++;
                        setState(() => _pageProgress = 0.05);
                        final provider = context.read<DownloaderProvider>();
                        provider.setDetectedPdfUrls(const []);
                        if (url != null) {
                          _browserUrlController.text = url.toString();
                          provider.setBrowserUrl(url.toString());
                        }
                      },
                      onProgressChanged: (controller, progress) {
                        if (!mounted) return;
                        setState(() => _pageProgress = progress / 100);
                        if (progress == 100) {
                          _pullToRefreshController?.endRefreshing();
                        }
                      },
                      onLoadStop: (controller, url) async {
                        if (!mounted) return;
                        setState(() => _pageProgress = 1);
                        _pullToRefreshController?.endRefreshing();
                        if (url != null) {
                          _browserUrlController.text = url.toString();
                          context
                              .read<DownloaderProvider>()
                              .setBrowserUrl(url.toString());
                        }
                        await _scanPdfLinks();
                      },
                      shouldOverrideUrlLoading: (controller, action) async {
                        final uri = action.request.url;
                        if (uri == null) {
                          return NavigationActionPolicy.ALLOW;
                        }
                        final href = uri.toString();
                        if (PdfUrlUtils.looksLikePdfUrl(href)) {
                          final provider = context.read<DownloaderProvider>();
                          if (provider.downloading) {
                            // No capturamos: deja navegar para no atrapar al usuario.
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Ya hay una descarga en curso.',
                                  ),
                                ),
                              );
                            }
                            return NavigationActionPolicy.ALLOW;
                          }
                          // Evita abrir el PDF dentro del WebView (callejón sin salida).
                          unawaited(_downloadPdfLink(href));
                          return NavigationActionPolicy.CANCEL;
                        }
                        return NavigationActionPolicy.ALLOW;
                      },
                      onDownloadStarting: (controller, request) async {
                        final href = request.url.toString();
                        final mime = request.mimeType?.toLowerCase() ?? '';
                        final isPdf = PdfUrlUtils.looksLikePdfUrl(href) ||
                            mime.contains('pdf');
                        if (!isPdf) return null;
                        unawaited(_downloadPdfLink(href));
                        // Evita el diálogo/descarga nativa del WebView.
                        return DownloadStartResponse(
                          handled: true,
                          action: DownloadStartResponseAction.CANCEL,
                        );
                      },
                      onReceivedError: (controller, request, error) {
                        _pullToRefreshController?.endRefreshing();
                        if (!mounted) return;
                        // Solo avisar en errores del documento principal.
                        if (request.isForMainFrame ?? true) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                'No se pudo cargar la página.',
                              ),
                            ),
                          );
                        }
                      },
                    ),
            ),
          ),
        ],
      ),
    ),
    );
  }
}

class _DirectUrlBar extends StatelessWidget {
  const _DirectUrlBar({
    required this.controller,
    required this.downloading,
    required this.progress,
    required this.onDownload,
  });

  final TextEditingController controller;
  final bool downloading;
  final double progress;
  final VoidCallback onDownload;

  @override
  Widget build(BuildContext context) {
    final colors = AppPalette.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'URL directa de PDF',
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: colors.accent,
                ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: controller,
                  enabled: !downloading,
                  keyboardType: TextInputType.url,
                  textInputAction: TextInputAction.done,
                  decoration: const InputDecoration(
                    hintText: 'https://ejemplo.com/archivo.pdf',
                    isDense: true,
                  ),
                  onSubmitted: (_) => onDownload(),
                ),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: downloading ? null : onDownload,
                child: const Text('Descargar'),
              ),
            ],
          ),
          if (downloading) ...[
            const SizedBox(height: 10),
            LinearProgressIndicator(
              value: progress <= 0 || progress >= 1 ? null : progress,
              color: colors.accent,
              backgroundColor: colors.border,
            ),
          ],
        ],
      ),
    );
  }
}

class _BrowserChrome extends StatelessWidget {
  const _BrowserChrome({
    required this.controller,
    required this.pageProgress,
    required this.detectedCount,
    required this.onSubmit,
    required this.onBack,
    required this.onForward,
    required this.onReload,
  });

  final TextEditingController controller;
  final double pageProgress;
  final int detectedCount;
  final ValueChanged<String> onSubmit;
  final VoidCallback onBack;
  final VoidCallback onForward;
  final VoidCallback onReload;

  @override
  Widget build(BuildContext context) {
    final colors = AppPalette.of(context);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
          child: Row(
            children: [
              IconButton(
                tooltip: 'Atrás',
                onPressed: onBack,
                icon: Icon(Icons.arrow_back, color: colors.textMuted),
              ),
              IconButton(
                tooltip: 'Adelante',
                onPressed: onForward,
                icon: Icon(Icons.arrow_forward, color: colors.textMuted),
              ),
              IconButton(
                tooltip: 'Recargar',
                onPressed: onReload,
                icon: Icon(Icons.refresh, color: colors.textMuted),
              ),
              Expanded(
                child: TextField(
                  controller: controller,
                  keyboardType: TextInputType.url,
                  textInputAction: TextInputAction.go,
                  decoration: const InputDecoration(
                    isDense: true,
                    hintText: 'Buscar o abrir URL',
                  ),
                  onSubmitted: onSubmit,
                ),
              ),
            ],
          ),
        ),
        if (pageProgress > 0 && pageProgress < 1)
          LinearProgressIndicator(
            value: pageProgress,
            minHeight: 2,
            color: colors.accent,
            backgroundColor: colors.border,
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              detectedCount > 0
                  ? '$detectedCount enlace(s) PDF detectado(s)'
                  : 'Mini-navegador privado · sin telemetría',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: detectedCount > 0 ? colors.accent : colors.textMuted,
                  ),
            ),
          ),
        ),
      ],
    );
  }
}
