import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import 'ink_stroke_painter.dart';

/// Lienzo para capturar una firma electrónica simple (trazo manuscrito).
class SignaturePad extends StatefulWidget {
  const SignaturePad({
    super.key,
    required this.onStrokesChanged,
    this.initialStrokes = const [],
    this.height = 168,
  });

  final ValueChanged<List<List<List<double>>>> onStrokesChanged;

  /// Trazos normalizados (0–1) para precargar (p. ej. plantilla dibujada).
  final List<List<List<double>>> initialStrokes;
  final double height;

  @override
  State<SignaturePad> createState() => SignaturePadState();
}

class SignaturePadState extends State<SignaturePad> {
  final List<List<Offset>> _strokes = [];
  List<Offset>? _current;
  Size _padSize = Size.zero;
  bool _seedApplied = false;

  @override
  void didUpdateWidget(covariant SignaturePad oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_sameStrokes(oldWidget.initialStrokes, widget.initialStrokes)) {
      _seedApplied = false;
      _applySeedIfReady(_padSize);
    }
  }

  bool _sameStrokes(
    List<List<List<double>>> a,
    List<List<List<double>>> b,
  ) {
    if (identical(a, b)) return true;
    if (a.length != b.length) return false;
    return a.toString() == b.toString();
  }

  void _applySeedIfReady(Size size) {
    if (_seedApplied || size.width <= 0 || size.height <= 0) return;
    if (widget.initialStrokes.isEmpty) {
      _seedApplied = true;
      return;
    }
    _seedApplied = true;
    _padSize = size;
    setState(() {
      _strokes
        ..clear()
        ..addAll(
          widget.initialStrokes.map(
            (stroke) => stroke
                .map(
                  (point) => Offset(
                    (point[0].clamp(0.0, 1.0) * size.width).toDouble(),
                    (point[1].clamp(0.0, 1.0) * size.height).toDouble(),
                  ),
                )
                .toList(),
          ),
        );
      _current = null;
    });
    _emit();
  }

  void clear() {
    setState(() {
      _strokes.clear();
      _current = null;
    });
    widget.onStrokesChanged(const []);
  }

  bool get hasInk => _strokes.any((stroke) => stroke.length >= 2);

  /// Expone trazos normalizados (para tests / validación directa).
  List<List<List<double>>> get normalizedStrokes => _normalize(_padSize);

  void _emit() {
    widget.onStrokesChanged(_normalize(_padSize));
  }

  List<List<List<double>>> _normalize(Size size) {
    if (size.width <= 0 || size.height <= 0) return const [];

    return _strokes
        .where((stroke) => stroke.length >= 2)
        .map(
          (stroke) => stroke
              .map(
                (point) => <double>[
                  (point.dx / size.width).clamp(0.0, 1.0),
                  (point.dy / size.height).clamp(0.0, 1.0),
                ],
              )
              .toList(),
        )
        .toList(growable: false);
  }

  void _start(Offset local, Size padSize) {
    _padSize = padSize;
    final clamped = _clampToPad(local, padSize);
    setState(() {
      _current = [clamped];
      _strokes.add(_current!);
    });
  }

  void _update(Offset local, Size padSize) {
    final current = _current;
    if (current == null) return;
    _padSize = padSize;
    final clamped = _clampToPad(local, padSize);
    final last = current.last;
    if ((clamped - last).distance < 1.2) return;
    setState(() => current.add(clamped));
  }

  void _end() {
    // Un toque puntual no firma: exige al menos 2 puntos por trazo.
    final current = _current;
    if (current != null && current.length < 2) {
      setState(() {
        if (_strokes.isNotEmpty && identical(_strokes.last, current)) {
          _strokes.removeLast();
        }
        _current = null;
      });
    } else {
      _current = null;
    }
    _emit();
  }

  Offset _clampToPad(Offset local, Size size) {
    if (size == Size.zero) return local;
    return Offset(
      local.dx.clamp(0.0, size.width),
      local.dy.clamp(0.0, size.height),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = HermesColors.of(context);
    final absoluteStrokes = _strokes
        .map(
          (stroke) => stroke
              .map((point) => <double>[point.dx, point.dy])
              .toList(),
        )
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Text(
              'Dibuja tu firma',
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: colors.textMuted,
                  ),
            ),
            const Spacer(),
            TextButton(
              onPressed: hasInk ? clear : null,
              child: Text(
                'Limpiar',
                style: TextStyle(
                  color: hasInk ? AppColors.obsidianAccent : colors.textMuted,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          height: widget.height,
          decoration: BoxDecoration(
            color: colors.surface,
            border: Border.all(color: colors.border),
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final padSize =
                  Size(constraints.maxWidth, constraints.maxHeight);
              if (!_seedApplied) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted) _applySeedIfReady(padSize);
                });
              }
              return GestureDetector(
                behavior: HitTestBehavior.opaque,
                onPanStart: (details) =>
                    _start(details.localPosition, padSize),
                onPanUpdate: (details) =>
                    _update(details.localPosition, padSize),
                onPanEnd: (_) => _end(),
                onPanCancel: _end,
                child: CustomPaint(
                  painter: InkStrokePainter(
                    strokes: absoluteStrokes,
                    color: colors.text,
                    strokeWidth: 2.4,
                    normalized: false,
                  ),
                  size: padSize,
                  child: Stack(
                    children: [
                      if (!hasInk)
                        Center(
                          child: Text(
                            'Firma aquí',
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(color: colors.textMuted),
                          ),
                        ),
                      Align(
                        alignment: Alignment.bottomCenter,
                        child: Padding(
                          padding: const EdgeInsets.only(bottom: 14),
                          child: Container(
                            height: 1,
                            margin: const EdgeInsets.symmetric(horizontal: 24),
                            color: colors.border,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
