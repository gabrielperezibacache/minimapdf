import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../domain/pdf_text_service.dart';
import '../pdf_text_selection.dart';

/// Capa de selección de texto: arrastra un rectángulo y resalta las palabras
/// del PDF cubiertas, notificando el texto seleccionado.
class TextSelectionLayer extends StatefulWidget {
  const TextSelectionLayer({
    super.key,
    required this.lines,
    required this.onSelectionChanged,
  });

  final List<PdfLineBox> lines;
  final ValueChanged<String> onSelectionChanged;

  @override
  State<TextSelectionLayer> createState() => _TextSelectionLayerState();
}

class _TextSelectionLayerState extends State<TextSelectionLayer> {
  Offset? _startPx;
  Offset? _currentPx;
  Size _size = Size.zero;

  Rect? get _selectionNorm {
    final a = _startPx;
    final b = _currentPx;
    if (a == null || b == null || _size.width <= 0 || _size.height <= 0) {
      return null;
    }
    final rect = Rect.fromPoints(a, b);
    return Rect.fromLTRB(
      (rect.left / _size.width).clamp(0.0, 1.0),
      (rect.top / _size.height).clamp(0.0, 1.0),
      (rect.right / _size.width).clamp(0.0, 1.0),
      (rect.bottom / _size.height).clamp(0.0, 1.0),
    );
  }

  void _emit() {
    final sel = _selectionNorm;
    if (sel == null) {
      widget.onSelectionChanged('');
      return;
    }
    widget.onSelectionChanged(
      selectedTextFromRect(lines: widget.lines, selection: sel),
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        _size = Size(constraints.maxWidth, constraints.maxHeight);
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onPanStart: (d) => setState(() {
            _startPx = d.localPosition;
            _currentPx = d.localPosition;
          }),
          onPanUpdate: (d) {
            setState(() => _currentPx = d.localPosition);
            _emit();
          },
          onPanEnd: (_) => _emit(),
          onTapUp: (_) {
            setState(() {
              _startPx = null;
              _currentPx = null;
            });
            widget.onSelectionChanged('');
          },
          child: CustomPaint(
            painter: _SelectionPainter(
              lines: widget.lines,
              selection: _selectionNorm,
            ),
            size: Size.infinite,
          ),
        );
      },
    );
  }
}

class _SelectionPainter extends CustomPainter {
  _SelectionPainter({required this.lines, required this.selection});

  final List<PdfLineBox> lines;
  final Rect? selection;

  @override
  void paint(Canvas canvas, Size size) {
    // Pista tenue de las palabras seleccionables.
    final hint = Paint()
      ..color = AppColors.ebonyAccent.withValues(alpha: 0.10)
      ..style = PaintingStyle.fill;
    for (final line in lines) {
      canvas.drawRect(
        Rect.fromLTWH(
          line.rect.x * size.width,
          line.rect.y * size.height,
          line.rect.width * size.width,
          line.rect.height * size.height,
        ),
        hint,
      );
    }

    final sel = selection;
    if (sel == null) return;

    // Resalta las palabras cubiertas por la selección.
    final selected = wordsInRect(
      lines: lines,
      selection: sel,
    );
    final hl = Paint()
      ..color = AppColors.ebonyAccent.withValues(alpha: 0.38)
      ..style = PaintingStyle.fill;
    for (final w in selected) {
      canvas.drawRect(
        Rect.fromLTWH(
          w.rect.x * size.width,
          w.rect.y * size.height,
          w.rect.width * size.width,
          w.rect.height * size.height,
        ),
        hl,
      );
    }

    // Rectángulo de arrastre.
    final rectPx = Rect.fromLTRB(
      sel.left * size.width,
      sel.top * size.height,
      sel.right * size.width,
      sel.bottom * size.height,
    );
    final border = Paint()
      ..color = AppColors.ebonyAccent
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawRect(rectPx, border);
  }

  @override
  bool shouldRepaint(_SelectionPainter old) =>
      old.selection != selection || old.lines != lines;
}
