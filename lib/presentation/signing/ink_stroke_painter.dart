import 'package:flutter/material.dart';

/// Pinta trazos normalizados (0–1) o en coordenadas absolutas del lienzo.
class InkStrokePainter extends CustomPainter {
  InkStrokePainter({
    required this.strokes,
    required this.color,
    this.strokeWidth = 2.0,
    this.normalized = true,
    this.blendMode = BlendMode.srcOver,
  });

  /// Trazos como listas de puntos `[x, y]`.
  final List<List<List<double>>> strokes;
  final Color color;
  final double strokeWidth;
  final bool normalized;
  final BlendMode blendMode;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..blendMode = blendMode;

    for (final stroke in strokes) {
      if (stroke.length < 2) continue;
      final path = Path();
      final first = stroke.first;
      path.moveTo(
        normalized ? first[0] * size.width : first[0],
        normalized ? first[1] * size.height : first[1],
      );
      for (var i = 1; i < stroke.length; i++) {
        final point = stroke[i];
        path.lineTo(
          normalized ? point[0] * size.width : point[0],
          normalized ? point[1] * size.height : point[1],
        );
      }
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant InkStrokePainter oldDelegate) {
    return oldDelegate.strokes != strokes ||
        oldDelegate.color != color ||
        oldDelegate.strokeWidth != strokeWidth ||
        oldDelegate.normalized != normalized ||
        oldDelegate.blendMode != blendMode;
  }
}
