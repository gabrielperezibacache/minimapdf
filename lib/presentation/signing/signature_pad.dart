import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import 'ink_stroke_painter.dart';

/// Lienzo para capturar una firma electrónica simple (trazo manuscrito).
class SignaturePad extends StatefulWidget {
  const SignaturePad({
    super.key,
    required this.onStrokesChanged,
    this.height = 168,
  });

  final ValueChanged<List<List<List<double>>>> onStrokesChanged;
  final double height;

  @override
  State<SignaturePad> createState() => SignaturePadState();
}

class SignaturePadState extends State<SignaturePad> {
  final List<List<Offset>> _strokes = [];
  List<Offset>? _current;
  Size _padSize = Size.zero;

  void clear() {
    setState(() {
      _strokes.clear();
      _current = null;
    });
    widget.onStrokesChanged(const []);
  }

  bool get hasInk => _strokes.any((stroke) => stroke.length >= 2);

  void _emit() {
    final size = _padSize;
    if (size.width <= 0 || size.height <= 0) {
      widget.onStrokesChanged(const []);
      return;
    }

    final normalized = _strokes
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
        .toList();
    widget.onStrokesChanged(normalized);
  }

  void _start(Offset local) {
    final clamped = _clampToPad(local);
    setState(() {
      _current = [clamped];
      _strokes.add(_current!);
    });
  }

  void _update(Offset local) {
    final current = _current;
    if (current == null) return;
    final clamped = _clampToPad(local);
    final last = current.last;
    if ((clamped - last).distance < 1.2) return;
    setState(() => current.add(clamped));
  }

  void _end() {
    _current = null;
    _emit();
  }

  Offset _clampToPad(Offset local) {
    final size = _padSize;
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
              if (_padSize != padSize) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted) _padSize = padSize;
                });
              }
              return GestureDetector(
                behavior: HitTestBehavior.opaque,
                onPanStart: (details) {
                  _padSize = padSize;
                  _start(details.localPosition);
                },
                onPanUpdate: (details) => _update(details.localPosition),
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
