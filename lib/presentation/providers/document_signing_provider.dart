import 'package:flutter/foundation.dart';

import '../../data/datasources/library_local_datasource.dart';
import '../../data/models/document_signature.dart';
import '../../domain/electronic_signature_service.dart';

/// Firmas electrónicas del documento abierto en el lector.
class DocumentSigningProvider extends ChangeNotifier {
  DocumentSigningProvider(
    this._datasource, {
    this._signatureService = const ElectronicSignatureService(),
  });

  final LibraryLocalDatasource _datasource;
  final ElectronicSignatureService _signatureService;

  int? _bookId;
  List<DocumentSignature> _signatures = const [];
  bool _loading = false;
  bool _saving = false;
  String? _error;

  List<DocumentSignature> get signatures => _signatures;
  bool get loading => _loading;
  bool get saving => _saving;
  String? get error => _error;

  /// Último nombre de firmante usado en este documento (para rellenar el form).
  String? get lastSignerName {
    if (_signatures.isEmpty) return null;
    return _signatures.last.signerName;
  }

  List<DocumentSignature> signaturesForPage(int pageNumber) {
    return _signatures
        .where((signature) => signature.pageNumber == pageNumber)
        .toList(growable: false);
  }

  Future<void> loadForBook(int bookId) async {
    _bookId = bookId;
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      _signatures = await _datasource.listSignatures(bookId);
    } catch (_) {
      _error = 'No se pudieron cargar las firmas.';
      _signatures = const [];
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  /// Firma la página actual (dibujada o mecanografiada) y persiste localmente.
  Future<DocumentSignature?> signPage({
    required int pageNumber,
    required SignatureDraft draft,
  }) async {
    final bookId = _bookId;
    if (bookId == null) {
      _error = 'Documento no disponible para firmar.';
      notifyListeners();
      return null;
    }

    _saving = true;
    _error = null;
    notifyListeners();

    try {
      final signature = _signatureService.signDocument(
        bookId: bookId,
        pageNumber: pageNumber,
        draft: draft,
        existingOnPage: signaturesForPage(pageNumber),
      );
      final saved = await _datasource.insertSignature(signature);
      _signatures = [..._signatures, saved]
        ..sort((a, b) {
          final byPage = a.pageNumber.compareTo(b.pageNumber);
          if (byPage != 0) return byPage;
          return a.signedAt.compareTo(b.signedAt);
        });
      return saved;
    } on SignatureValidationException catch (error) {
      _error = error.message;
      return null;
    } catch (_) {
      _error = 'No se pudo guardar la firma.';
      return null;
    } finally {
      _saving = false;
      notifyListeners();
    }
  }

  /// Actualiza la posición relativa del sello en la página.
  Future<void> moveSignature({
    required DocumentSignature signature,
    required double offsetX,
    required double offsetY,
  }) async {
    final id = signature.id;
    if (id == null) return;

    final moved = signature.copyWith(
      offsetX: offsetX.clamp(0.0, 1.0).toDouble(),
      offsetY: offsetY.clamp(0.0, 1.0).toDouble(),
    );

    // Actualización optimista para que el arrastre se sienta fluido.
    _signatures = [
      for (final item in _signatures)
        if (item.id == id) moved else item,
    ];
    notifyListeners();

    try {
      await _datasource.saveSignature(moved);
    } catch (_) {
      _error = 'No se pudo mover la firma.';
      final bookId = _bookId;
      if (bookId != null) await loadForBook(bookId);
    }
  }

  Future<void> deleteSignature(DocumentSignature signature) async {
    final bookId = _bookId;
    final id = signature.id;
    if (bookId == null || id == null) return;

    await _datasource.removeSignature(id);
    _signatures = [
      for (final item in _signatures)
        if (item.id != id) item,
    ];
    notifyListeners();
  }

  void clearError() {
    if (_error == null) return;
    _error = null;
    notifyListeners();
  }
}
