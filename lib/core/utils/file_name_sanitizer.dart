/// Sanitiza nombres de archivo para evitar colisiones y caracteres inválidos.
abstract final class FileNameSanitizer {
  static final RegExp _invalid = RegExp(r'[<>:"/\\|?*\x00-\x1F]');

  /// Nombres reservados de Windows (dispositivo), sin extensión.
  static const Set<String> _windowsReserved = {
    'con', 'prn', 'aux', 'nul',
    'com1', 'com2', 'com3', 'com4', 'com5', 'com6', 'com7', 'com8', 'com9',
    'lpt1', 'lpt2', 'lpt3', 'lpt4', 'lpt5', 'lpt6', 'lpt7', 'lpt8', 'lpt9',
  };

  /// Devuelve un nombre seguro con extensión `.pdf`.
  static String sanitize(String rawName, {String fallback = 'documento'}) {
    var name = rawName.trim();
    if (name.toLowerCase().endsWith('.pdf')) {
      name = name.substring(0, name.length - 4);
    }

    name = name.replaceAll(_invalid, '_').replaceAll(RegExp(r'\s+'), '_');
    name = name.replaceAll(RegExp(r'_+'), '_');
    name = _stripEdgeJunk(name);

    if (name.isEmpty || RegExp(r'^\.+$').hasMatch(name)) {
      name = fallback;
    }
    if (_windowsReserved.contains(name.toLowerCase())) {
      name = '${fallback}_$name';
    }
    if (name.length > 80) {
      name = _stripEdgeJunk(name.substring(0, 80));
      if (name.isEmpty) name = fallback;
      if (_windowsReserved.contains(name.toLowerCase())) {
        name = '${fallback}_$name';
      }
    }

    return '$name.pdf';
  }

  static String _stripEdgeJunk(String value) {
    return value.replaceAll(RegExp(r'^[._]+|[._]+$'), '');
  }

  /// Genera un nombre único añadiendo un sufijo si ya existe en [existingNames].
  static String uniqueName(String sanitized, Set<String> existingNames) {
    if (!existingNames.contains(sanitized.toLowerCase())) {
      return sanitized;
    }

    final base = sanitized.substring(0, sanitized.length - 4);
    var index = 2;
    while (true) {
      final candidate = '${base}_$index.pdf';
      if (!existingNames.contains(candidate.toLowerCase())) {
        return candidate;
      }
      index++;
    }
  }
}
