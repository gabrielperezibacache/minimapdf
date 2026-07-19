import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:pdfx/pdfx.dart';

import '../../../core/theme/ebony_pdf_filter.dart';
import '../../../data/models/document_signature.dart';
import '../../../data/models/page_annotation.dart';
import '../../providers/reader_annotations_provider.dart';
import '../../signing/signature_overlay.dart';
import 'page_annotations_layer.dart';

/// Página PDF con sellos de firma y anotaciones anclados al rectángulo de la página.
///
/// El filtro Ébano se aplica solo a la imagen, no a los sellos ni anotaciones.
/// El tamaño del widget usa [fallbackSize] (puntos PDF) para coincidir con
/// PhotoView `childSize` y con la geometría de exportación.
class SignedPdfPage extends StatelessWidget {
  const SignedPdfPage({
    super.key,
    required this.pageImageFuture,
    required this.pageNumber,
    required this.signatures,
    required this.ebonyFilter,
    required this.placementMode,
    required this.onPlaceTap,
    required this.onMove,
    required this.onDelete,
    this.annotations = const [],
    this.activeTool = AnnotationTool.none,
    this.annotationsEnabled = true,
    this.onCreateAnnotation,
    this.onOpenAnnotation,
    this.onDeleteAnnotation,
    this.fallbackSize = const Size(595, 842),
  });

  final Future<PdfPageImage> pageImageFuture;
  final int pageNumber;
  final List<DocumentSignature> signatures;
  final bool ebonyFilter;
  final bool placementMode;
  final void Function(int pageNumber, double x, double y) onPlaceTap;
  final void Function(DocumentSignature signature, double x, double y) onMove;
  final ValueChanged<DocumentSignature> onDelete;
  final List<PageAnnotation> annotations;
  final AnnotationTool activeTool;
  final bool annotationsEnabled;
  final Future<void> Function({
    required int pageNumber,
    required double x,
    required double y,
    required double width,
    required double height,
  })? onCreateAnnotation;
  final ValueChanged<PageAnnotation>? onOpenAnnotation;
  final ValueChanged<PageAnnotation>? onDeleteAnnotation;
  final Size fallbackSize;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<PdfPageImage>(
      future: pageImageFuture,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return SizedBox.fromSize(
            size: fallbackSize,
            child: const Center(child: Text('Error al cargar la página')),
          );
        }
        final image = snapshot.data;
        if (image == null) {
          return SizedBox.fromSize(
            size: fallbackSize,
            child: const Center(
              child: SizedBox(
                width: 28,
                height: 28,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          );
        }

        final bytes = Uint8List.fromList(image.bytes);

        return SizedBox(
          width: fallbackSize.width,
          height: fallbackSize.height,
          child: Stack(
            fit: StackFit.expand,
            children: [
              EbonyPdfFilter.wrap(
                enabled: ebonyFilter,
                child: Image.memory(
                  bytes,
                  fit: BoxFit.fill,
                  gaplessPlayback: true,
                  filterQuality: FilterQuality.medium,
                ),
              ),
              if (onCreateAnnotation != null &&
                  onOpenAnnotation != null &&
                  onDeleteAnnotation != null)
                PageAnnotationsLayer(
                  annotations: annotations,
                  activeTool: activeTool,
                  enabled: annotationsEnabled && !placementMode,
                  onCreateRect: ({
                    required double x,
                    required double y,
                    required double width,
                    required double height,
                  }) {
                    return onCreateAnnotation!(
                      pageNumber: pageNumber,
                      x: x,
                      y: y,
                      width: width,
                      height: height,
                    );
                  },
                  onOpenAnnotation: onOpenAnnotation!,
                  onDeleteAnnotation: onDeleteAnnotation!,
                ),
              SignatureLayer(
                signatures: signatures,
                topReserve: 0,
                bottomReserve: 0,
                placementMode: placementMode,
                onPlaceTap: (x, y) => onPlaceTap(pageNumber, x, y),
                onMove: onMove,
                onDelete: onDelete,
              ),
            ],
          ),
        );
      },
    );
  }
}
