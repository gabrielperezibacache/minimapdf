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
  String? _error;

  List<DocumentSignature> get signatures => _signatures;
  bool get loading => _loading;
  String? get error => _error;

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
    } catch (error) {
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

    try {
      final signature = _signatureService.signDocument(
        bookId: bookId,
        pageNumber: pageNumber,
        draft: draft,
      );
      final saved = await _datasource.insertSignature(signature);
      await loadForBook(bookId);
      return saved;
    } on SignatureValidationException catch (error) {
      _error = error.message;
      notifyListeners();
      return null;
    } catch (_) {
      _error = 'No se pudo guardar la firma.';
      notifyListeners();
      return null;
    }
  }

  Future<void> deleteSignature(DocumentSignature signature) async {
    final bookId = _bookId;
    final id = signature.id;
    if (bookId == null || id == null) return;
    await _datasource.removeSignature(id);
    await loadForBook(bookId);
  }

  void clearError() {
    if (_error == null) return;
    _error = null;
    notifyListeners();
  }
}
