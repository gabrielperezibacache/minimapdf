import 'dart:typed_data';
import 'dart:ui' as ui;

/// Banda vertical de texto detectada en la página, normalizada 0–1.
class TextBand {
  const TextBand({required this.top, required this.bottom});

  final double top;
  final double bottom;

  double get center => (top + bottom) / 2;
  double get height => bottom - top;
}

/// Perfil de "tinta" (densidad de píxeles oscuros) por fila, normalizado 0–1.
///
/// [buckets] filas de resolución sobre la altura de la imagen. Cada valor es la
/// fracción media de oscuridad de esa franja (0 = claro, 1 = negro).
List<double> inkProfileFromRgba(
  Uint8List rgba,
  int width,
  int height, {
  int buckets = 240,
  int colStride = 4,
}) {
  if (width <= 0 || height <= 0 || rgba.length < width * height * 4) {
    return const [];
  }
  final safeBuckets = buckets < 1
      ? 1
      : (buckets > height ? height : buckets);
  final sums = List<double>.filled(safeBuckets, 0);
  final counts = List<int>.filled(safeBuckets, 0);
  final stride = colStride.clamp(1, width);

  for (var y = 0; y < height; y++) {
    final bucket = (y * safeBuckets ~/ height).clamp(0, safeBuckets - 1);
    final rowOffset = y * width * 4;
    var rowDark = 0.0;
    var rowCount = 0;
    for (var x = 0; x < width; x += stride) {
      final i = rowOffset + x * 4;
      final r = rgba[i];
      final g = rgba[i + 1];
      final b = rgba[i + 2];
      // Luminancia perceptual; oscuridad = 1 - luma.
      final luma = (0.299 * r + 0.587 * g + 0.114 * b) / 255.0;
      rowDark += 1.0 - luma;
      rowCount++;
    }
    if (rowCount > 0) {
      sums[bucket] += rowDark / rowCount;
      counts[bucket]++;
    }
  }

  final profile = List<double>.filled(safeBuckets, 0);
  for (var i = 0; i < safeBuckets; i++) {
    profile[i] = counts[i] > 0 ? sums[i] / counts[i] : 0;
  }
  return profile;
}

/// Detecta bandas de texto a partir de un perfil de tinta por fila.
///
/// Una franja pertenece a una línea de texto si su tinta supera un umbral
/// relativo al máximo del perfil. Franjas contiguas se fusionan en una banda.
List<TextBand> detectTextBands(
  List<double> profile, {
  double thresholdRatio = 0.28,
  double minBandFraction = 0.006,
}) {
  if (profile.length < 4) return const [];
  var maxInk = 0.0;
  var minInk = double.infinity;
  for (final v in profile) {
    if (v > maxInk) maxInk = v;
    if (v < minInk) minInk = v;
  }
  if (maxInk <= 0 || maxInk - minInk < 1e-6) return const [];

  final threshold = minInk + (maxInk - minInk) * thresholdRatio;
  final n = profile.length;
  final bands = <TextBand>[];
  int? runStart;
  for (var i = 0; i < n; i++) {
    final above = profile[i] >= threshold;
    if (above && runStart == null) {
      runStart = i;
    } else if (!above && runStart != null) {
      _addBand(bands, runStart, i, n, minBandFraction);
      runStart = null;
    }
  }
  if (runStart != null) {
    _addBand(bands, runStart, n, n, minBandFraction);
  }
  return bands;
}

void _addBand(List<TextBand> out, int start, int end, int n, double minFrac) {
  final top = start / n;
  final bottom = end / n;
  if (bottom - top >= minFrac) {
    out.add(TextBand(top: top, bottom: bottom));
  }
}

/// Ejecuta la detección de bandas sobre una imagen ya decodificada.
Future<List<TextBand>> detectTextBandsFromImage(ui.Image image) async {
  final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
  if (data == null) return const [];
  final profile = inkProfileFromRgba(
    data.buffer.asUint8List(),
    image.width,
    image.height,
  );
  return detectTextBands(profile);
}

/// Imanta un trazo normalizado a la banda de texto más cercana.
///
/// - Marcado: alinea a la línea central de la banda.
/// - Subrayado: alinea al borde inferior de la banda.
///
/// Devuelve un trazo recto (2 puntos) o `null` si no hay banda adecuada.
List<List<double>>? snapStrokeToBands({
  required List<List<double>> stroke,
  required List<TextBand> bands,
  required bool underline,
  double maxDistance = 0.06,
}) {
  if (stroke.length < 2 || bands.isEmpty) return null;

  var minX = stroke.first[0];
  var maxX = stroke.first[0];
  var sumY = 0.0;
  for (final p in stroke) {
    if (p[0] < minX) minX = p[0];
    if (p[0] > maxX) maxX = p[0];
    sumY += p[1];
  }
  final meanY = sumY / stroke.length;

  TextBand? best;
  var bestDist = double.infinity;
  for (final band in bands) {
    final dist = meanY >= band.top && meanY <= band.bottom
        ? 0.0
        : (meanY < band.top ? band.top - meanY : meanY - band.bottom);
    if (dist < bestDist) {
      bestDist = dist;
      best = band;
    }
  }
  if (best == null || bestDist > maxDistance) return null;

  final y = (underline ? best.bottom : best.center).clamp(0.0, 1.0);
  if (maxX - minX < 1e-4) return null;
  return [
    [minX.clamp(0.0, 1.0), y],
    [maxX.clamp(0.0, 1.0), y],
  ];
}

/// Endereza un trazo a una línea horizontal (respaldo cuando no hay bandas).
List<List<double>> straightenStroke({
  required List<List<double>> stroke,
  required bool underline,
}) {
  var minX = stroke.first[0];
  var maxX = stroke.first[0];
  var minY = stroke.first[1];
  var maxY = stroke.first[1];
  var sumY = 0.0;
  for (final p in stroke) {
    if (p[0] < minX) minX = p[0];
    if (p[0] > maxX) maxX = p[0];
    if (p[1] < minY) minY = p[1];
    if (p[1] > maxY) maxY = p[1];
    sumY += p[1];
  }
  final y = (underline ? maxY : sumY / stroke.length).clamp(0.0, 1.0);
  return [
    [minX.clamp(0.0, 1.0), y],
    [maxX.clamp(0.0, 1.0), y],
  ];
}
