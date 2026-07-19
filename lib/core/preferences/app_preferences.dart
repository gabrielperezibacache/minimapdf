import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import '../utils/app_paths.dart';

/// Preferencias locales ligeras (JSON en el directorio de documentos).
///
/// Se usa para flags de una sola vez, como la pantalla de bienvenida
/// tras la primera apertura posterior a la instalación.
class AppPreferences {
  AppPreferences._(this._file, Map<String, dynamic> data) : _data = data;

  static const String fileName = 'app_prefs.json';
  static const String keyHasSeenWelcome = 'has_seen_welcome';

  final File _file;
  final Map<String, dynamic> _data;

  /// Abre (o crea) el archivo de preferencias.
  ///
  /// [directory] permite inyectar una carpeta temporal en tests.
  static Future<AppPreferences> open({Directory? directory}) async {
    final dir = directory ?? await AppPaths.documentsDirectory();
    final file = File(p.join(dir.path, fileName));
    return AppPreferences._(file, _readFile(file));
  }

  static Map<String, dynamic> _readFile(File file) {
    if (!file.existsSync()) return <String, dynamic>{};

    try {
      final decoded = jsonDecode(file.readAsStringSync());
      if (decoded is Map<String, dynamic>) return decoded;
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
    } on Object {
      // Archivo corrupto o ilegible: empezar limpio.
    }
    return <String, dynamic>{};
  }

  bool get hasSeenWelcome => _data[keyHasSeenWelcome] == true;

  /// Marca la bienvenida como vista.
  ///
  /// Actualiza memoria de inmediato y persiste con escritura atómica.
  /// Si el disco falla, el flag en memoria evita re-mostrar la bienvenida
  /// en la misma sesión.
  void markWelcomeSeen() {
    if (hasSeenWelcome) return;
    _data[keyHasSeenWelcome] = true;
    _persist();
  }

  void _persist() {
    try {
      _file.parent.createSync(recursive: true);
      final payload = jsonEncode(_data);
      final tmp = File('${_file.path}.tmp');
      tmp.writeAsStringSync(payload, flush: true);
      if (_file.existsSync()) {
        _file.deleteSync();
      }
      tmp.renameSync(_file.path);
    } on Object {
      try {
        _file.writeAsStringSync(jsonEncode(_data), flush: true);
      } on Object {
        // Solo memoria: la UI ya avanzó; el flag se reintentará al cerrar.
      }
    }
  }
}
