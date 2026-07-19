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
  int _moveGeneration = 0;

  List<DocumentSignature> get signatures => _signatures;
  bool get loading => _loading;
  bool get saving => _saving;
  String? get error => _error;

  /// Firmante de la firma más reciente (por [DocumentSignature.signedAt]).
  String? get lastSignerName {
    if (_signatures.isEmpty) return null;
    var latest = _signatures.first;
    for (final signature in _signatures.skip(1)) {
      if (signature.signedAt.isAfter(latest.signedAt)) {
        latest = signature;
      }
    }
    return latest.signerName;
  }

  List<DocumentSignature> signaturesForPage(int pageNumber) {
    return _signatures
        .where((signature) => signature.pageNumber == pageNumber)
        .toList(growable: false);
  }

  int _loadGeneration = 0;

  Future<void> loadForBook(int bookId) async {
    _bookId = bookId;
    final generation = ++_loadGeneration;
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      final loaded = await _datasource.listSignatures(bookId);
      // Ignora cargas obsoletos si hubo otra carga/firma más reciente.
      if (generation != _loadGeneration || _bookId != bookId) return;
      // Si hay una firma en curso, no pises el estado optimista local.
      if (_saving) return;
      _signatures = loaded;
    } catch (_) {
      if (generation != _loadGeneration || _bookId != bookId) return;
      _error = 'No se pudieron cargar las firmas.';
      if (!_saving) {
        _signatures = const [];
      }
    } finally {
      if (generation == _loadGeneration) {
        _loading = false;
        notifyListeners();
      }
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
    if (_saving) {
      _error = 'Ya hay una firma en curso.';
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
      // Merge por id: una carga concurrente pudo haber traído ya la fila.
      _signatures = [
        for (final item in _signatures)
          if (item.id != saved.id) item,
        saved,
      ]..sort((a, b) {
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
    if (!offsetX.isFinite || !offsetY.isFinite) return;

    final nextX = offsetX.clamp(0.0, 1.0).toDouble();
    final nextY = offsetY.clamp(0.0, 1.0).toDouble();
    if ((signature.offsetX - nextX).abs() < 0.001 &&
        (signature.offsetY - nextY).abs() < 0.001) {
      return;
    }

    final moved = signature.copyWith(offsetX: nextX, offsetY: nextY);
    final generation = ++_moveGeneration;

    // Actualización optimista para que el arrastre se sienta fluido.
    _signatures = [
      for (final item in _signatures)
        if (item.id == id) moved else item,
    ];
    notifyListeners();

    try {
      await _datasource.saveSignature(moved);
      // Ignora respuestas antiguas si hubo movimientos más recientes.
      if (generation != _moveGeneration) return;
    } catch (_) {
      if (generation != _moveGeneration) return;
      _error = 'No se pudo mover la firma.';
      final bookId = _bookId;
      if (bookId != null) await loadForBook(bookId);
    }
  }

  Future<bool> deleteSignature(DocumentSignature signature) async {
    final bookId = _bookId;
    final id = signature.id;
    if (bookId == null || id == null) return false;

    try {
      await _datasource.removeSignature(id);
      _signatures = [
        for (final item in _signatures)
          if (item.id != id) item,
      ];
      notifyListeners();
      return true;
    } catch (_) {
      _error = 'No se pudo eliminar la firma.';
      notifyListeners();
      return false;
    }
  }

  void clearError() {
    if (_error == null) return;
    _error = null;
    notifyListeners();
  }
}
