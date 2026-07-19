import 'dart:async';

/// Serializa escrituras al directorio `library/` (import y descargas).
///
/// Evita que dos flujos elijan el mismo nombre único y se pisen al fallar
/// la inserción en DB (borrado del destino del otro).
abstract final class LibraryFileCoordinator {
  static Future<void>? _tail;

  /// Ejecuta [action] en exclusiva respecto a otras llamadas.
  static Future<T> runExclusive<T>(Future<T> Function() action) async {
    final previous = _tail;
    final gate = Completer<void>();
    _tail = gate.future;

    if (previous != null) {
      try {
        await previous;
      } catch (_) {
        // La cola no debe romper por errores previos.
      }
    }

    try {
      return await action();
    } finally {
      gate.complete();
      if (identical(_tail, gate.future)) {
        _tail = null;
      }
    }
  }

  /// Solo para tests.
  static void debugReset() {
    _tail = null;
  }
}
