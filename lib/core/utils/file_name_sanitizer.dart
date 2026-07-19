/// Sanitiza nombres de archivo para evitar colisiones y caracteres inválidos.
abstract final class FileNameSanitizer {
  static final RegExp _invalid = RegExp(r'[<>:"/\\|?*\x00-\x1F]');

  /// Devuelve un nombre seguro con extensión `.pdf`.
  static String sanitize(String rawName, {String fallback = 'documento'}) {
    var name = rawName.trim();
    if (name.toLowerCase().endsWith('.pdf')) {
      name = name.substring(0, name.length - 4);
    }

    name = name.replaceAll(_invalid, '_').replaceAll(RegExp(r'\s+'), '_');
    name = name.replaceAll(RegExp(r'_+'), '_');
    name = name.replaceAll(RegExp(r'^_|_$'), '');

    if (name.isEmpty) name = fallback;
    if (name.length > 80) name = name.substring(0, 80);

    return '$name.pdf';
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
