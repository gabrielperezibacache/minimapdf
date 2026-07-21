import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../domain/pdf_text_service.dart';
import '../eager_gesture_capture.dart';
import '../pdf_text_selection.dart';

/// Capa de selección de texto: arrastra un rectángulo y resalta las palabras
/// del PDF cubiertas, notificando el texto seleccionado.
///
/// Usa [Listener] + recognizers eager para ganar al [PageView]/PhotoView]
/// desde el primer toque (sin arena lenta ni “segundo intento”).
class TextSelectionLayer extends StatefulWidget {
  const TextSelectionLayer({
    super.key,
    required this.lines,
    required this.onSelectionChanged,
    this.externalPointerRouting = false,
  });

  final List<PdfLineBox> lines;
  final ValueChanged<String> onSelectionChanged;
  /// Si true, el padre enruta punteros vía [TextSelectionLayerState.handlePointer*].
  final bool externalPointerRouting;

  @override
  State<TextSelectionLayer> createState() => TextSelectionLayerState();
}

class TextSelectionLayerState extends State<TextSelectionLayer> {
  Offset? _startPx;
  Offset? _currentPx;
  Size _size = Size.zero;
  int? _activePointer;

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
    // Toque casi puntual: seleccionar la palabra bajo el dedo.
    final tiny = sel.width * _size.width < 8 && sel.height * _size.height < 8;
    if (tiny) {
      final point = Offset(
        (sel.left + sel.right) / 2,
        (sel.top + sel.bottom) / 2,
      );
      final word = _wordAtNormalized(point);
      widget.onSelectionChanged(word?.text ?? '');
      return;
    }
    widget.onSelectionChanged(
      selectedTextFromRect(lines: widget.lines, selection: sel),
    );
  }

  PdfWordBox? _wordAtNormalized(Offset point) {
    for (final line in widget.lines) {
      for (final word in line.words) {
        final r = word.rect;
        if (point.dx >= r.x &&
            point.dx <= r.x + r.width &&
            point.dy >= r.y &&
            point.dy <= r.y + r.height) {
          return word;
        }
      }
    }
    return null;
  }

  void _clear() {
    _activePointer = null;
    _startPx = null;
    _currentPx = null;
  }

  void handlePointerDown(PointerDownEvent event, {Offset? localOverride}) {
    _onPointerDown(event, localOverride ?? event.localPosition);
  }

  void handlePointerMove(PointerMoveEvent event, {Offset? localOverride}) {
    _onPointerMove(event, localOverride ?? event.localPosition);
  }

  void handlePointerUp(PointerUpEvent event, {Offset? localOverride}) {
    _onPointerUp(event, localOverride ?? event.localPosition);
  }

  void handlePointerCancel(PointerCancelEvent event, {Offset? localOverride}) {
    _onPointerCancel(event);
  }

  void _onPointerDown(PointerDownEvent event, Offset localPosition) {
    if (_activePointer != null) return;
    _activePointer = event.pointer;
    setState(() {
      _startPx = localPosition;
      _currentPx = localPosition;
    });
  }

  void _onPointerMove(PointerMoveEvent event, Offset localPosition) {
    if (event.pointer != _activePointer) return;
    setState(() => _currentPx = localPosition);
    _emit();
  }

  void _onPointerUp(PointerUpEvent event, Offset localPosition) {
    if (event.pointer != _activePointer) return;
    setState(() => _currentPx = localPosition);
    _emit();
    _activePointer = null;
  }

  void _onPointerCancel(PointerCancelEvent event) {
    if (event.pointer != _activePointer) return;
    _emit();
    _activePointer = null;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        _size = Size(constraints.maxWidth, constraints.maxHeight);
        final paintChild = CustomPaint(
          size: _size,
          painter: _SelectionPainter(
            lines: widget.lines,
            selection: _selectionNorm,
          ),
        );

        if (widget.externalPointerRouting) {
          return paintChild;
        }

        return RawGestureDetector(
          behavior: HitTestBehavior.opaque,
          gestures: eagerCaptureGestures(debugOwner: this),
          child: Listener(
            behavior: HitTestBehavior.opaque,
            onPointerDown: (event) => _onPointerDown(event, event.localPosition),
            onPointerMove: (event) => _onPointerMove(event, event.localPosition),
            onPointerUp: (event) => _onPointerUp(event, event.localPosition),
            onPointerCancel: _onPointerCancel,
            child: paintChild,
          ),
        );
      },
    );
  }

  @override
  void didUpdateWidget(covariant TextSelectionLayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.lines, widget.lines) &&
        oldWidget.lines != widget.lines) {
      // Nueva página / texto: limpiar rectángulo de arrastre.
      if (_activePointer == null && (_startPx != null || _currentPx != null)) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted || _activePointer != null) return;
          setState(_clear);
          widget.onSelectionChanged('');
        });
      }
    }
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
      for (final word in line.words) {
        canvas.drawRect(
          Rect.fromLTWH(
            word.rect.x * size.width,
            word.rect.y * size.height,
            word.rect.width * size.width,
            word.rect.height * size.height,
          ),
          hint,
        );
      }
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
    final fill = Paint()
      ..color = AppColors.ebonyAccent.withValues(alpha: 0.12)
      ..style = PaintingStyle.fill;
    final border = Paint()
      ..color = AppColors.ebonyAccent
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawRect(rectPx, fill);
    canvas.drawRect(rectPx, border);
  }

  @override
  bool shouldRepaint(_SelectionPainter old) =>
      old.selection != selection || old.lines != lines;
}
