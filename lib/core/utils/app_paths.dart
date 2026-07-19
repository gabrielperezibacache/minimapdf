import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Resuelve directorios de la app con fallback para escritorio Linux.
abstract final class AppPaths {
  static Future<Directory> documentsDirectory() async {
    try {
      return await getApplicationDocumentsDirectory();
    } catch (_) {
      final home = Platform.environment['HOME'] ?? Directory.systemTemp.path;
      final dir = Directory(p.join(home, '.local', 'share', 'minimal_pdf'));
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }
      return dir;
    }
  }
}
