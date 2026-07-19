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
    var data = <String, dynamic>{};

    if (file.existsSync()) {
      try {
        final decoded = jsonDecode(file.readAsStringSync());
        if (decoded is Map<String, dynamic>) {
          data = decoded;
        } else if (decoded is Map) {
          data = Map<String, dynamic>.from(decoded);
        }
      } on Object {
        data = <String, dynamic>{};
      }
    }

    return AppPreferences._(file, data);
  }

  bool get hasSeenWelcome => _data[keyHasSeenWelcome] == true;

  /// Marca la bienvenida como vista y la persiste de forma síncrona.
  void markWelcomeSeen() {
    if (hasSeenWelcome) return;
    _data[keyHasSeenWelcome] = true;
    _file.parent.createSync(recursive: true);
    _file.writeAsStringSync(jsonEncode(_data));
  }
}
