import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/document_signature.dart';
import '../../data/models/signature_role.dart';
import '../../data/models/signature_type.dart';
import '../../domain/signature_stamp_geometry.dart';
import 'ink_stroke_painter.dart';

/// Capa de firmas posicionadas de forma relativa sobre el área del PDF.
class SignatureLayer extends StatelessWidget {
  const SignatureLayer({
    super.key,
    required this.signatures,
    required this.onMove,
    required this.onDelete,
    this.onPlaceTap,
    this.placementMode = false,
    this.signaturesInteractive = true,
    this.bottomReserve = 0,
    this.topReserve = 0,
  });

  final List<DocumentSignature> signatures;
  final Future<bool> Function(
    DocumentSignature signature,
    double x,
    double y,
  ) onMove;
  final ValueChanged<DocumentSignature> onDelete;

  /// Tap en zona vacía con coordenadas normalizadas (0–1).
  final void Function(double x, double y)? onPlaceTap;
  final bool placementMode;
  /// Si false, los sellos no se pueden arrastrar ni borrar (p. ej. exportando).
  final bool signaturesInteractive;
  final double bottomReserve;
  final double topReserve;

  @override
  Widget build(BuildContext context) {
    if (signatures.isEmpty && !placementMode) {
      return const SizedBox.shrink();
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final usableWidth = constraints.maxWidth;
        final rawUsableHeight =
            constraints.maxHeight - topReserve - bottomReserve;
        final pageSize = Size(
          usableWidth,
          rawUsableHeight >= SignatureStampGeometry.referenceStampWidth *
                  SignatureStampGeometry.heightOverWidth
              ? rawUsableHeight
              : constraints.maxHeight.clamp(1.0, double.infinity),
        );
        final stamp = SignatureStampGeometry.stampSizeFor(pageSize);
        final effectiveTopReserve =
            rawUsableHeight >= stamp.height ? topReserve : 0.0;
        final maxLeft = (pageSize.width - stamp.width)
            .clamp(0.0, pageSize.width)
            .toDouble();
        final maxTop = (pageSize.height - stamp.height)
            .clamp(0.0, pageSize.height)
            .toDouble();

        return Stack(
          children: [
            for (final signature in signatures)
              _PositionedSignature(
                key: ValueKey(signature.id ?? identityHashCode(signature)),
                signature: signature,
                stampSize: stamp,
                maxLeft: maxLeft,
                maxTop: maxTop,
                topReserve: effectiveTopReserve,
                interactive: signaturesInteractive && !placementMode,
                onMove: onMove,
                onDelete: onDelete,
              ),
            if (placementMode && onPlaceTap != null)
              Positioned.fill(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTapDown: (details) {
                    final dx = details.localPosition.dx;
                    final dy = details.localPosition.dy - effectiveTopReserve;
                    final x =
                        maxLeft <= 0 ? 0.0 : (dx / maxLeft).clamp(0.0, 1.0);
                    final y =
                        maxTop <= 0 ? 0.0 : (dy / maxTop).clamp(0.0, 1.0);
                    onPlaceTap!(x.toDouble(), y.toDouble());
                  },
                  child: ColoredBox(
                    color: AppColors.ebonyAccent.withValues(alpha: 0.08),
                    child: Align(
                      alignment: Alignment.topCenter,
                      child: Padding(
                        padding: EdgeInsets.only(top: effectiveTopReserve + 12),
                        child: Text(
                          'Toca donde quieres colocar la firma',
                          style: Theme.of(context)
                              .textTheme
                              .labelLarge
                              ?.copyWith(color: AppColors.ebonyAccent),
                        ),
                      ),
                    ),
                  ),
                ),
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
    required this.stampSize,
    required this.maxLeft,
    required this.maxTop,
    required this.topReserve,
    required this.interactive,
    required this.onMove,
    required this.onDelete,
  });

  final DocumentSignature signature;
  final Size stampSize;
  final double maxLeft;
  final double maxTop;
  final double topReserve;
  final bool interactive;
  final Future<bool> Function(
    DocumentSignature signature,
    double x,
    double y,
  ) onMove;
  final ValueChanged<DocumentSignature> onDelete;

  @override
  State<_PositionedSignature> createState() => _PositionedSignatureState();
}

class _PositionedSignatureState extends State<_PositionedSignature> {
  Offset _dragDelta = Offset.zero;
  bool _persisting = false;

  @override
  void didUpdateWidget(covariant _PositionedSignature oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.signature.offsetX != widget.signature.offsetX ||
        oldWidget.signature.offsetY != widget.signature.offsetY) {
      _dragDelta = Offset.zero;
      _persisting = false;
    }
  }

  (double, double) _clampedPosition() {
    final baseLeft = widget.signature.offsetX * widget.maxLeft;
    final baseTop = widget.signature.offsetY * widget.maxTop;
    final left = (baseLeft + _dragDelta.dx).clamp(0.0, widget.maxLeft);
    final top = (baseTop + _dragDelta.dy).clamp(0.0, widget.maxTop);
    return (left.toDouble(), top.toDouble());
  }

  Future<void> _commitDrag() async {
    if (_persisting) return;
    final pos = _clampedPosition();
    final nextX = widget.maxLeft <= 0 ? 0.0 : pos.$1 / widget.maxLeft;
    final nextY = widget.maxTop <= 0 ? 0.0 : pos.$2 / widget.maxTop;
    final shouldPersist = _dragDelta.distanceSquared > 1.0;
    final insignificant =
        (widget.signature.offsetX - nextX).abs() < 0.001 &&
            (widget.signature.offsetY - nextY).abs() < 0.001;
    if (!shouldPersist || insignificant) {
      if (mounted) setState(() => _dragDelta = Offset.zero);
      return;
    }
    _persisting = true;
    // Mantener delta hasta offsets nuevos; si falla, revertir.
    final ok = await widget.onMove(widget.signature, nextX, nextY);
    if (!mounted) return;
    _persisting = false;
    if (!ok) {
      setState(() => _dragDelta = Offset.zero);
    }
  }

  @override
  Widget build(BuildContext context) {
    final position = _clampedPosition();

    return Positioned(
      left: position.$1,
      top: widget.topReserve + position.$2,
      child: SignatureOverlay(
        signature: widget.signature,
        width: widget.stampSize.width,
        onDelete: widget.interactive
            ? () => widget.onDelete(widget.signature)
            : null,
        onDragUpdate: widget.interactive
            ? (delta) => setState(() => _dragDelta += delta)
            : null,
        onDragEnd: widget.interactive ? () => unawaited(_commitDrag()) : null,
        onDragCancel: widget.interactive
            ? () => setState(() => _dragDelta = Offset.zero)
            : null,
      ),
    );
  }
}

/// Sello visual de una firma electrónica sobre la página del PDF.
class SignatureOverlay extends StatelessWidget {
  const SignatureOverlay({
    super.key,
    required this.signature,
    this.width = SignatureStampGeometry.referenceStampWidth,
    this.onDelete,
    this.onDragUpdate,
    this.onDragEnd,
    this.onDragCancel,
  });

  final DocumentSignature signature;
  final double width;
  final VoidCallback? onDelete;
  final ValueChanged<Offset>? onDragUpdate;
  final VoidCallback? onDragEnd;
  final VoidCallback? onDragCancel;

  @override
  Widget build(BuildContext context) {
    final colors = AppPalette.of(context);
    final dateLabel = formatSignatureDate(signature.signedAt);
    final canDrag = onDragUpdate != null && onDragEnd != null;
    final scale = width / SignatureStampGeometry.referenceStampWidth;
    final height = width * SignatureStampGeometry.heightOverWidth;

    return GestureDetector(
      onPanUpdate: canDrag ? (details) => onDragUpdate!(details.delta) : null,
      onPanEnd: canDrag ? (_) => onDragEnd!() : null,
      onPanCancel: canDrag ? (onDragCancel ?? onDragEnd) : null,
      child: Material(
        color: colors.panel.withValues(alpha: 0.96),
        elevation: 0,
        child: Container(
          width: width,
          height: height,
          padding: EdgeInsets.fromLTRB(10 * scale, 8 * scale, 6 * scale, 8 * scale),
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.ebonyAccent, width: 1),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Icon(
                    signature.type == SignatureType.typed
                        ? Icons.text_fields
                        : Icons.gesture,
                    size: 14 * scale,
                    color: AppColors.ebonyAccent,
                  ),
                  SizedBox(width: 6 * scale),
                  Expanded(
                    child: Text(
                      '${signature.role.labelEs} · #${signature.signingOrder}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: AppColors.ebonyAccent,
                            fontSize: 11 * scale,
                          ),
                    ),
                  ),
                  if (onDelete != null)
                    Semantics(
                      button: true,
                      label: 'Eliminar firma',
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: onDelete,
                        child: Padding(
                          padding: EdgeInsets.all(4 * scale),
                          child: Icon(
                            Icons.close,
                            size: 14 * scale,
                            color: colors.textMuted,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              SizedBox(height: 4 * scale),
              Expanded(
                flex: 5,
                child: signature.type == SignatureType.typed
                    ? Text(
                        signature.displayText,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: 'serif',
                          fontStyle: FontStyle.italic,
                          fontSize: 20 * scale,
                          height: 1.1,
                          letterSpacing: 0.4,
                          color: colors.text,
                        ),
                      )
                    : CustomPaint(
                        painter: InkStrokePainter(
                          strokes: signature.inkStrokes,
                          color: colors.text,
                          strokeWidth: 1.9 * scale,
                        ),
                      ),
              ),
              SizedBox(height: 4 * scale),
              Text(
                signature.signerName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      fontSize: 11 * scale,
                    ),
              ),
              Text(
                dateLabel,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: colors.textMuted,
                      fontSize: 10 * scale,
                    ),
              ),
              if (signature.reason != null && signature.reason!.isNotEmpty)
                Text(
                  signature.reason!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: colors.textMuted,
                        fontSize: 10 * scale,
                      ),
                ),
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
