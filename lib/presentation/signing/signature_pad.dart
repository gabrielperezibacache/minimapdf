import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';

/// Lienzo para capturar una firma electrónica simple (trazo manuscrito).
class SignaturePad extends StatefulWidget {
  const SignaturePad({
    super.key,
    required this.onStrokesChanged,
    this.height = 160,
  });

  final ValueChanged<List<List<List<double>>>> onStrokesChanged;
  final double height;

  @override
  State<SignaturePad> createState() => SignaturePadState();
}

class SignaturePadState extends State<SignaturePad> {
  final List<List<Offset>> _strokes = [];
  List<Offset>? _current;

  void clear() {
    setState(() {
      _strokes.clear();
      _current = null;
    });
    widget.onStrokesChanged(const []);
  }

  bool get hasInk => _strokes.any((stroke) => stroke.length >= 2);

  void _emit() {
    final box = context.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) {
      widget.onStrokesChanged(const []);
      return;
    }
    final size = box.size;
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
    setState(() {
      _current = [local];
      _strokes.add(_current!);
    });
  }

  void _update(Offset local) {
    final current = _current;
    if (current == null) return;
    setState(() => current.add(local));
  }

  void _end() {
    _current = null;
    _emit();
  }

  @override
  Widget build(BuildContext context) {
    final colors = HermesColors.of(context);

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
              onPressed: clear,
              child: Text(
                'Limpiar',
                style: TextStyle(color: AppColors.obsidianAccent),
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
              return GestureDetector(
                behavior: HitTestBehavior.opaque,
                onPanStart: (details) => _start(details.localPosition),
                onPanUpdate: (details) => _update(details.localPosition),
                onPanEnd: (_) => _end(),
                onPanCancel: _end,
                child: CustomPaint(
                  painter: _InkPainter(
                    strokes: _strokes,
                    color: colors.text,
                  ),
                  size: Size(constraints.maxWidth, constraints.maxHeight),
                  child: Align(
                    alignment: Alignment.bottomCenter,
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Container(
                        height: 1,
                        margin: const EdgeInsets.symmetric(horizontal: 24),
                        color: colors.border,
                      ),
                    ),
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

class _InkPainter extends CustomPainter {
  _InkPainter({required this.strokes, required this.color});

  final List<List<Offset>> strokes;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2.2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    for (final stroke in strokes) {
      if (stroke.length < 2) continue;
      final path = Path()..moveTo(stroke.first.dx, stroke.first.dy);
      for (var i = 1; i < stroke.length; i++) {
        path.lineTo(stroke[i].dx, stroke[i].dy);
      }
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _InkPainter oldDelegate) {
    return oldDelegate.strokes != strokes || oldDelegate.color != color;
  }
}
