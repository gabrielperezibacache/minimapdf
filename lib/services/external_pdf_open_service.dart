import 'dart:async';
import 'dart:collection';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Bridges OS "Open with" / share intents that deliver a PDF path into Flutter.
///
/// Paths are queued (not dropped) so cold-start, welcome and concurrent opens
/// do not lose documents. Listeners should [takeNext] / drain after [start].
class ExternalPdfOpenService extends ChangeNotifier {
  ExternalPdfOpenService({
    MethodChannel? methodChannel,
    EventChannel? eventChannel,
  })  : _methodChannel =
            methodChannel ?? const MethodChannel('minimal_pdf/external_open'),
        _eventChannel = eventChannel ??
            const EventChannel('minimal_pdf/external_open/events');

  final MethodChannel _methodChannel;
  final EventChannel _eventChannel;

  StreamSubscription<dynamic>? _subscription;
  final ListQueue<String> _queue = ListQueue<String>();
  bool _started = false;
  bool _disposed = false;
  String? _lastEnqueued;
  DateTime? _lastEnqueuedAt;

  /// True when at least one path is waiting to be imported.
  bool get hasQueued => _queue.isNotEmpty;

  /// Snapshot of queued absolute paths (oldest first).
  List<String> get queuedPaths => List<String>.unmodifiable(_queue);

  /// Removes and returns the next path, or `null` if the queue is empty.
  String? takeNext() {
    if (_queue.isEmpty) return null;
    final next = _queue.removeFirst();
    notifyListeners();
    return next;
  }

  /// Puts [path] back at the front (e.g. import was busy).
  void requeue(String path) {
    final trimmed = path.trim();
    if (trimmed.isEmpty || _disposed) return;
    _queue.addFirst(trimmed);
    notifyListeners();
  }

  /// Encola al final (reintento tras fallo transitorio sin bloquear la cola).
  void queueLast(String path) {
    final trimmed = path.trim();
    if (trimmed.isEmpty || _disposed) return;
    if (_queue.contains(trimmed)) {
      notifyListeners();
      return;
    }
    _queue.addLast(trimmed);
    notifyListeners();
  }

  Future<void> start() async {
    if (_started || _disposed) return;
    _started = true;

    try {
      _subscription = _eventChannel.receiveBroadcastStream().listen(
        (dynamic event) {
          _enqueue(event?.toString());
        },
        onError: (Object error, StackTrace stack) {
          if (error is MissingPluginException) return;
          debugPrint('ExternalPdfOpenService stream error: $error');
        },
        cancelOnError: false,
      );
    } on MissingPluginException {
      // Desktop / tests without the native plugin.
    }

    // Drena todos los pendientes (p. ej. SEND_MULTIPLE) por si el EventChannel
    // aún no ha vaciado la cola nativa.
    try {
      for (var i = 0; i < 32 && !_disposed; i++) {
        final initial = await _methodChannel.invokeMethod<String>(
          'getInitialPdfPath',
        );
        final path = initial?.trim() ?? '';
        if (path.isEmpty) break;
        _enqueue(path);
      }
    } on PlatformException catch (e) {
      debugPrint('getInitialPdfPath failed: ${e.message}');
    } on MissingPluginException {
      // Desktop / tests without the native plugin.
    }
  }

  void _enqueue(String? raw) {
    if (_disposed) return;
    final path = raw?.trim() ?? '';
    if (path.isEmpty) return;

    // Evita duplicar el mismo path cuando EventChannel y getInitial coinciden,
    // o cuando iOS SceneDelegate + AppDelegate entregan la misma URL.
    final now = DateTime.now();
    if (_lastEnqueued == path &&
        _lastEnqueuedAt != null &&
        now.difference(_lastEnqueuedAt!) < const Duration(seconds: 2)) {
      return;
    }
    if (_queue.contains(path)) return;

    _lastEnqueued = path;
    _lastEnqueuedAt = now;
    _queue.addLast(path);
    notifyListeners();
  }

  /// Opens the system screen where the user can set Minimal PDF as the
  /// default handler for PDFs (Android) or app details (iOS).
  Future<bool> openDefaultAppsSettings() async {
    try {
      final result = await _methodChannel.invokeMethod<bool>(
        'openDefaultAppsSettings',
      );
      return result ?? false;
    } on PlatformException catch (e) {
      debugPrint('openDefaultAppsSettings failed: ${e.message}');
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _subscription?.cancel();
    _subscription = null;
    _queue.clear();
    super.dispose();
  }
}
