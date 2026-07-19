import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/document_signature.dart';
import '../../data/models/signature_type.dart';
import 'ink_stroke_painter.dart';

/// Capa de firmas posicionadas de forma relativa sobre el área del PDF.
class SignatureLayer extends StatelessWidget {
  const SignatureLayer({
    super.key,
    required this.signatures,
    required this.onMove,
    required this.onDelete,
    this.bottomReserve = 0,
    this.topReserve = 0,
  });

  final List<DocumentSignature> signatures;
  final void Function(DocumentSignature signature, double x, double y) onMove;
  final ValueChanged<DocumentSignature> onDelete;
  final double bottomReserve;
  final double topReserve;

  static const double stampWidth = 196;
  static const double stampHeightEstimate = 118;

  @override
  Widget build(BuildContext context) {
    if (signatures.isEmpty) return const SizedBox.shrink();

    return LayoutBuilder(
      builder: (context, constraints) {
        final usableWidth = constraints.maxWidth;
        final usableHeight =
            (constraints.maxHeight - topReserve - bottomReserve)
                .clamp(1.0, constraints.maxHeight);
        final maxLeft = (usableWidth - stampWidth).clamp(0.0, usableWidth);
        final maxTop =
            (usableHeight - stampHeightEstimate).clamp(0.0, usableHeight);

        return Stack(
          children: [
            for (final signature in signatures)
              _PositionedSignature(
                key: ValueKey(signature.id ?? identityHashCode(signature)),
                signature: signature,
                maxLeft: maxLeft,
                maxTop: maxTop,
                topReserve: topReserve,
                onMove: onMove,
                onDelete: onDelete,
              ),
          ],
        );
      },
    );
  }
}

class _PositionedSignature extends StatefulWidget {
  const _PositionedSignature({
    super.key,
    required this.signature,
    required this.maxLeft,
    required this.maxTop,
    required this.topReserve,
    required this.onMove,
    required this.onDelete,
  });

  final DocumentSignature signature;
  final double maxLeft;
  final double maxTop;
  final double topReserve;
  final void Function(DocumentSignature signature, double x, double y) onMove;
  final ValueChanged<DocumentSignature> onDelete;

  @override
  State<_PositionedSignature> createState() => _PositionedSignatureState();
}

class _PositionedSignatureState extends State<_PositionedSignature> {
  Offset _dragDelta = Offset.zero;

  @override
  void didUpdateWidget(covariant _PositionedSignature oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.signature.offsetX != widget.signature.offsetX ||
        oldWidget.signature.offsetY != widget.signature.offsetY) {
      _dragDelta = Offset.zero;
    }
  }

  (double, double) _clampedPosition() {
    final baseLeft = widget.signature.offsetX * widget.maxLeft;
    final baseTop = widget.signature.offsetY * widget.maxTop;
    final left = (baseLeft + _dragDelta.dx).clamp(0.0, widget.maxLeft);
    final top = (baseTop + _dragDelta.dy).clamp(0.0, widget.maxTop);
    return (left.toDouble(), top.toDouble());
  }

  @override
  Widget build(BuildContext context) {
    final position = _clampedPosition();

    return Positioned(
      left: position.$1,
      top: widget.topReserve + position.$2,
      child: SignatureOverlay(
        signature: widget.signature,
        onDelete: () => widget.onDelete(widget.signature),
        onDragUpdate: (delta) {
          setState(() => _dragDelta += delta);
        },
        onDragEnd: () {
          // Recalcular con el delta actual (no cerrar sobre el build).
          final pos = _clampedPosition();
          final nextX =
              widget.maxLeft <= 0 ? 0.0 : pos.$1 / widget.maxLeft;
          final nextY = widget.maxTop <= 0 ? 0.0 : pos.$2 / widget.maxTop;
          final shouldPersist = _dragDelta.distanceSquared > 1.0;
          if (!shouldPersist) {
            setState(() => _dragDelta = Offset.zero);
            return;
          }
          // No resetear delta aquí: evita un salto visual a la posición
          // antigua antes de que el provider actualice offsetX/Y.
          // didUpdateWidget limpia el delta al recibir los nuevos offsets.
          widget.onMove(widget.signature, nextX, nextY);
        },
        onDragCancel: () {
          setState(() => _dragDelta = Offset.zero);
        },
      ),
    );
  }
}

/// Sello visual de una firma electrónica sobre la página del PDF.
class SignatureOverlay extends StatelessWidget {
  const SignatureOverlay({
    super.key,
    required this.signature,
    this.onDelete,
    this.onDragUpdate,
    this.onDragEnd,
    this.onDragCancel,
  });

  final DocumentSignature signature;
  final VoidCallback? onDelete;
  final ValueChanged<Offset>? onDragUpdate;
  final VoidCallback? onDragEnd;
  final VoidCallback? onDragCancel;

  @override
  Widget build(BuildContext context) {
    final colors = HermesColors.of(context);
    final dateLabel = formatSignatureDate(signature.signedAt);
    final canDrag = onDragUpdate != null && onDragEnd != null;

    return GestureDetector(
      onPanUpdate: canDrag ? (details) => onDragUpdate!(details.delta) : null,
      onPanEnd: canDrag ? (_) => onDragEnd!() : null,
      onPanCancel: canDrag ? (onDragCancel ?? onDragEnd) : null,
      child: Material(
        color: colors.panel.withValues(alpha: 0.96),
        elevation: 0,
        child: Container(
          width: SignatureLayer.stampWidth,
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
                      'Firmado electrónicamente',
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
                      icon:
                          Icon(Icons.close, size: 14, color: colors.textMuted),
                    ),
                ],
              ),
              const SizedBox(height: 6),
              if (signature.type == SignatureType.typed)
                Text(
                  signature.displayText,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
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
                    painter: InkStrokePainter(
                      strokes: signature.inkStrokes,
                      color: colors.text,
                      strokeWidth: 1.9,
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
              if (canDrag) ...[
                const SizedBox(height: 4),
                Text(
                  'Arrastra para colocar',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: colors.textMuted,
                        fontSize: 10,
                      ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

String formatSignatureDate(DateTime value) {
  final local = value.toLocal();
  final dd = local.day.toString().padLeft(2, '0');
  final mm = local.month.toString().padLeft(2, '0');
  final yyyy = local.year.toString();
  final hh = local.hour.toString().padLeft(2, '0');
  final min = local.minute.toString().padLeft(2, '0');
  return '$dd/$mm/$yyyy $hh:$min';
}
