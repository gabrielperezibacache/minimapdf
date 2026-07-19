import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Bridges OS "Open with" / share intents that deliver a PDF path into Flutter.
class ExternalPdfOpenService {
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
  final _controller = StreamController<String>.broadcast();
  bool _started = false;

  /// Paths of PDFs the OS asked the app to open (copied into app cache).
  Stream<String> get incomingPaths => _controller.stream;

  Future<void> start() async {
    if (_started) return;
    _started = true;

    _subscription = _eventChannel.receiveBroadcastStream().listen(
      (dynamic event) {
        final path = event?.toString().trim() ?? '';
        if (path.isNotEmpty) {
          _controller.add(path);
        }
      },
      onError: (Object error, StackTrace stack) {
        debugPrint('ExternalPdfOpenService stream error: $error');
      },
    );

    try {
      final initial = await _methodChannel.invokeMethod<String>(
        'getInitialPdfPath',
      );
      final path = initial?.trim() ?? '';
      if (path.isNotEmpty) {
        _controller.add(path);
      }
    } on PlatformException catch (e) {
      debugPrint('getInitialPdfPath failed: ${e.message}');
    } on MissingPluginException {
      // Desktop / tests without the native plugin.
    }
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

  Future<void> dispose() async {
    await _subscription?.cancel();
    _subscription = null;
    await _controller.close();
    _started = false;
  }
}
