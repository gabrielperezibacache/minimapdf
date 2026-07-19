import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:pdfx/pdfx.dart';

import '../../../core/theme/ebony_pdf_filter.dart';
import '../../../data/models/document_signature.dart';
import '../../signing/signature_overlay.dart';

/// Página PDF con sellos de firma anclados al rectángulo de la página.
///
/// El filtro Ébano se aplica solo a la imagen, no a los sellos.
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
    this.fallbackSize = const Size(595, 842),
  });

  final Future<PdfPageImage> pageImageFuture;
  final int pageNumber;
  final List<DocumentSignature> signatures;
  final bool ebonyFilter;
  final bool placementMode;
  final void Function(double x, double y) onPlaceTap;
  final void Function(DocumentSignature signature, double x, double y) onMove;
  final ValueChanged<DocumentSignature> onDelete;
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

        final width = (image.width ?? fallbackSize.width).toDouble();
        final height = (image.height ?? fallbackSize.height).toDouble();
        final bytes = Uint8List.fromList(image.bytes);

        return SizedBox(
          width: width,
          height: height,
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
              SignatureLayer(
                signatures: signatures,
                topReserve: 0,
                bottomReserve: 0,
                placementMode: placementMode,
                onPlaceTap: onPlaceTap,
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
