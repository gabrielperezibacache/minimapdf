import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/document_signature.dart';
import '../../data/models/signature_type.dart';

/// Sello visual de una firma electrónica sobre la página del PDF.
class SignatureOverlay extends StatelessWidget {
  const SignatureOverlay({
    super.key,
    required this.signature,
    this.onDelete,
  });

  final DocumentSignature signature;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final colors = HermesColors.of(context);
    final dateLabel = _formatDate(signature.signedAt);

    return Material(
      color: colors.panel.withValues(alpha: 0.94),
      child: Container(
        width: 200,
        padding: const EdgeInsets.fromLTRB(10, 8, 6, 8),
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.obsidianAccent, width: 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Icon(
                  signature.type == SignatureType.typed
                      ? Icons.text_fields
                      : Icons.gesture,
                  size: 14,
                  color: AppColors.obsidianAccent,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    signature.type.labelEs,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: AppColors.obsidianAccent,
                        ),
                  ),
                ),
                if (onDelete != null)
                  IconButton(
                    tooltip: 'Eliminar firma',
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                    constraints:
                        const BoxConstraints(minWidth: 24, minHeight: 24),
                    onPressed: onDelete,
                    icon: Icon(Icons.close, size: 14, color: colors.textMuted),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            if (signature.type == SignatureType.typed)
              Text(
                signature.displayText,
                style: TextStyle(
                  fontFamily: 'serif',
                  fontStyle: FontStyle.italic,
                  fontSize: 22,
                  height: 1.1,
                  letterSpacing: 0.4,
                  color: colors.text,
                ),
              )
            else
              SizedBox(
                height: 48,
                child: CustomPaint(
                  painter: _StoredInkPainter(
                    strokes: signature.inkStrokes,
                    color: colors.text,
                  ),
                ),
              ),
            const SizedBox(height: 6),
            Text(
              signature.signerName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelSmall,
            ),
            Text(
              dateLabel,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: colors.textMuted,
                  ),
            ),
            if (signature.reason != null && signature.reason!.isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(
                signature.reason!,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: colors.textMuted,
                    ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime value) {
    final local = value.toLocal();
    final dd = local.day.toString().padLeft(2, '0');
    final mm = local.month.toString().padLeft(2, '0');
    final yyyy = local.year.toString();
    final hh = local.hour.toString().padLeft(2, '0');
    final min = local.minute.toString().padLeft(2, '0');
    return '$dd/$mm/$yyyy $hh:$min';
  }
}

class _StoredInkPainter extends CustomPainter {
  _StoredInkPainter({required this.strokes, required this.color});

  final List<List<List<double>>> strokes;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.8
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    for (final stroke in strokes) {
      if (stroke.length < 2) continue;
      final path = Path()
        ..moveTo(stroke.first[0] * size.width, stroke.first[1] * size.height);
      for (var i = 1; i < stroke.length; i++) {
        path.lineTo(stroke[i][0] * size.width, stroke[i][1] * size.height);
      }
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _StoredInkPainter oldDelegate) {
    return oldDelegate.strokes != strokes || oldDelegate.color != color;
  }
}
