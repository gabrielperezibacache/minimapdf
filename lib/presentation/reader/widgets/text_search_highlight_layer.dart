import 'package:flutter/material.dart';

import '../annotation_ink.dart' show MarkupRect;

/// Resalta coincidencias de búsqueda sobre la página (coords normalizadas 0–1).
class TextSearchHighlightLayer extends StatelessWidget {
  const TextSearchHighlightLayer({
    super.key,
    required this.highlights,
    this.activeIndex,
  });

  final List<MarkupRect> highlights;

  /// Índice del resaltado activo dentro de [highlights], o null.
  final int? activeIndex;

  @override
  Widget build(BuildContext context) {
    if (highlights.isEmpty) return const SizedBox.shrink();
    return IgnorePointer(
      child: CustomPaint(
        painter: _SearchHighlightPainter(
          highlights: highlights,
          activeIndex: activeIndex,
        ),
        child: const SizedBox.expand(),
      ),
    );
  }
}

class _SearchHighlightPainter extends CustomPainter {
  _SearchHighlightPainter({
    required this.highlights,
    required this.activeIndex,
  });

  final List<MarkupRect> highlights;
  final int? activeIndex;

  static const Color _idle = Color(0x66F5C542);
  static const Color _active = Color(0xAAFF8A3D);

  @override
  void paint(Canvas canvas, Size size) {
    for (var i = 0; i < highlights.length; i++) {
      final r = highlights[i];
      final rect = Rect.fromLTWH(
        r.x * size.width,
        r.y * size.height,
        r.width * size.width,
        r.height * size.height,
      ).inflate(1.5);
      final paint = Paint()
        ..color = i == activeIndex ? _active : _idle
        ..style = PaintingStyle.fill;
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(2)),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _SearchHighlightPainter oldDelegate) {
    return oldDelegate.activeIndex != activeIndex ||
        oldDelegate.highlights != highlights;
  }
}
