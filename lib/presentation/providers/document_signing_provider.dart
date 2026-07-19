import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../../data/datasources/library_local_datasource.dart';
import '../../data/models/book.dart';
import '../../data/models/document_signature.dart';
import '../../data/models/signature_role.dart';
import '../../data/models/signature_template.dart';
import '../../data/models/signature_type.dart';
import '../../domain/electronic_signature_service.dart';
import '../../domain/signed_pdf_export_service.dart';

/// Firmas electrónicas del documento abierto en el lector.
class DocumentSigningProvider extends ChangeNotifier {
  DocumentSigningProvider(
    this._datasource, {
    this._signatureService = const ElectronicSignatureService(),
    SignedPdfExportService? exportService,
  }) : _exportService = exportService ?? SignedPdfExportService();

  final LibraryLocalDatasource _datasource;
  final ElectronicSignatureService _signatureService;
  final SignedPdfExportService _exportService;

  int? _bookId;
  Book? _book;
  List<DocumentSignature> _signatures = const [];
  List<SignatureTemplate> _templates = const [];
  bool _loading = false;
  bool _saving = false;
  bool _exporting = false;
  bool _placementMode = false;
  bool _disposed = false;
  double? _pendingOffsetX;
  double? _pendingOffsetY;
  String? _error;
  int _moveGeneration = 0;
  int _loadGeneration = 0;
  int _dataGeneration = 0;

  List<DocumentSignature> get signatures => _signatures;
  List<SignatureTemplate> get templates => _templates;
  bool get hasSignatures => _signatures.isNotEmpty;
  bool get loading => _loading;
  bool get saving => _saving;
  bool get exporting => _exporting;
  bool get placementMode => _placementMode;
  double? get pendingOffsetX => _pendingOffsetX;
  double? get pendingOffsetY => _pendingOffsetY;
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

  SignatureRole? get lastRole {
    if (_signatures.isEmpty) return null;
    var latest = _signatures.first;
    for (final signature in _signatures.skip(1)) {
      if (signature.signedAt.isAfter(latest.signedAt)) {
        latest = signature;
      }
    }
    return latest.role;
  }

  List<DocumentSignature> signaturesForPage(int pageNumber) {
    return _signatures
        .where((signature) => signature.pageNumber == pageNumber)
        .toList(growable: false);
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    super.dispose();
  }

  Future<void> loadForBook(Book book) async {
    _book = book;
    final bookId = book.id;
    if (bookId == null) {
      _bookId = null;
      _signatures = const [];
      _placementMode = false;
      _pendingOffsetX = null;
      _pendingOffsetY = null;
      _notify();
      return;
    }
    _bookId = bookId;
    final generation = ++_loadGeneration;
    final dataGenerationAtStart = _dataGeneration;
    _loading = true;
    _error = null;
    _notify();
    try {
      final loaded = await _datasource.listSignatures(bookId);
      final templates = await _datasource.listSignatureTemplates();
      if (generation != _loadGeneration || _bookId != bookId) return;
      // Si hubo mutación local durante la carga, no pisar con datos viejos.
      if (_saving || dataGenerationAtStart != _dataGeneration) {
        if (dataGenerationAtStart == _dataGeneration) {
          _templates = templates;
        }
        return;
      }
      _signatures = loaded;
      _templates = templates;
    } catch (_) {
      if (generation != _loadGeneration || _bookId != bookId) return;
      _error = 'No se pudieron cargar las firmas.';
      // Conserva la lista previa si ya había firmas en memoria.
    } finally {
      if (generation == _loadGeneration) {
        _loading = false;
        _notify();
      }
    }
  }

  /// Compatibilidad con llamadas antiguas por id.
  Future<void> loadForBookId(int bookId) async {
    final book = await _datasource.findBookById(bookId);
    if (book == null) {
      _bookId = bookId;
      _book = null;
      try {
        _signatures = await _datasource.listSignatures(bookId);
        _templates = await _datasource.listSignatureTemplates();
      } catch (_) {
        _error = 'No se pudieron cargar las firmas.';
      }
      _notify();
      return;
    }
    await loadForBook(book);
  }

  void beginPlacementMode() {
    _placementMode = true;
    _pendingOffsetX = null;
    _pendingOffsetY = null;
    _notify();
  }

  void cancelPlacementMode() {
    if (!_placementMode && _pendingOffsetX == null) return;
    _placementMode = false;
    _pendingOffsetX = null;
    _pendingOffsetY = null;
    _notify();
  }

  /// Registra la zona tocada (0–1) y sale del modo colocación.
  void placeSignatureAt({required double offsetX, required double offsetY}) {
    _pendingOffsetX = offsetX.clamp(0.0, 1.0).toDouble();
    _pendingOffsetY = offsetY.clamp(0.0, 1.0).toDouble();
    _placementMode = false;
    _notify();
  }

  void clearPendingPlacement() {
    _pendingOffsetX = null;
    _pendingOffsetY = null;
    _notify();
  }

  /// Firma la página actual (dibujada o mecanografiada) y persiste localmente.
  Future<DocumentSignature?> signPage({
    required int pageNumber,
    required SignatureDraft draft,
  }) async {
    final bookId = _bookId;
    if (bookId == null) {
      _error = 'Documento no disponible para firmar.';
      _notify();
      return null;
    }
    if (_saving) {
      _error = 'Ya hay una firma en curso.';
      _notify();
      return null;
    }
    if (_exporting) {
      _error = 'Espera a que termine la exportación.';
      _notify();
      return null;
    }

    _saving = true;
    _error = null;
    _notify();

    try {
      final order = await _datasource.nextSigningOrder(bookId);
      final withPlacement = SignatureDraft(
        type: draft.type,
        signerName: draft.signerName,
        typedText: draft.typedText,
        inkStrokes: draft.inkStrokes,
        reason: draft.reason,
        role: draft.role,
        offsetX: draft.offsetX ?? _pendingOffsetX,
        offsetY: draft.offsetY ?? _pendingOffsetY,
        saveAsTemplate: draft.saveAsTemplate,
        templateName: draft.templateName,
      );

      final signature = _signatureService.signDocument(
        bookId: bookId,
        pageNumber: pageNumber,
        draft: withPlacement,
        existingOnPage: signaturesForPage(pageNumber),
        signingOrder: order,
      );
      final saved = await _datasource.insertSignature(signature);
      _dataGeneration++;

      _signatures = [
        for (final item in _signatures)
          if (item.id != saved.id) item,
        saved,
      ]..sort((a, b) {
          final byOrder = a.signingOrder.compareTo(b.signingOrder);
          if (byOrder != 0) return byOrder;
          final byPage = a.pageNumber.compareTo(b.pageNumber);
          if (byPage != 0) return byPage;
          return a.signedAt.compareTo(b.signedAt);
        });
      _pendingOffsetX = null;
      _pendingOffsetY = null;

      if (draft.saveAsTemplate) {
        try {
          await _saveTemplateFromDraft(draft);
        } catch (_) {
          _error = 'Firma guardada, pero no se pudo crear la plantilla.';
        }
      }

      return saved;
    } on SignatureValidationException catch (error) {
      _error = error.message;
      return null;
    } catch (_) {
      _error = 'No se pudo guardar la firma.';
      return null;
    } finally {
      _saving = false;
      _notify();
    }
  }

  Future<void> _saveTemplateFromDraft(SignatureDraft draft) async {
    final requestedName = draft.templateName?.trim() ?? '';
    final name = _signatureService.normalizePersonText(
      requestedName.isNotEmpty ? requestedName : draft.signerName,
    );
    if (name.isEmpty) {
      throw StateError('Nombre de plantilla vacío.');
    }

    final template = SignatureTemplate(
      name: name,
      type: draft.type,
      signerName: _signatureService.normalizePersonText(draft.signerName),
      typedText: draft.type == SignatureType.typed
          ? _signatureService.normalizePersonText(
              draft.typedText ?? draft.signerName,
            )
          : null,
      inkJson: draft.type == SignatureType.drawn
          ? jsonEncode(_signatureService.normalizeStrokes(draft.inkStrokes))
          : null,
      role: draft.role,
      createdAt: DateTime.now(),
    );
    final saved = await _datasource.insertSignatureTemplate(template);
    _templates = [saved, ..._templates];
  }

  Future<void> reloadTemplates() async {
    _templates = await _datasource.listSignatureTemplates();
    _notify();
  }

  Future<bool> deleteTemplate(SignatureTemplate template) async {
    final id = template.id;
    if (id == null) return false;
    await _datasource.removeSignatureTemplate(id);
    _templates = [
      for (final item in _templates)
        if (item.id != id) item,
    ];
    _notify();
    return true;
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
    _dataGeneration++;

    _signatures = [
      for (final item in _signatures)
        if (item.id == id) moved else item,
    ];
    _notify();

    try {
      await _datasource.saveSignature(moved);
      if (generation != _moveGeneration) return;
    } catch (_) {
      if (generation != _moveGeneration) return;
      _error = 'No se pudo mover la firma.';
      final book = _book;
      if (book != null) await loadForBook(book);
    }
  }

  Future<bool> deleteSignature(DocumentSignature signature) async {
    final bookId = _bookId;
    final id = signature.id;
    if (bookId == null || id == null) return false;

    try {
      await _datasource.removeSignature(id);
      _dataGeneration++;
      _signatures = [
        for (final item in _signatures)
          if (item.id != id) item,
      ];
      _notify();
      return true;
    } catch (_) {
      _error = 'No se pudo eliminar la firma.';
      _notify();
      return false;
    }
  }

  /// Exporta PDF firmado (sellos aplanados) + manifiesto SHA-256 e importa
  /// la copia a la biblioteca.
  Future<SignedPdfExportResult?> exportSignedPdf() async {
    final book = _book;
    if (book == null) {
      _error = 'Documento no disponible.';
      _notify();
      return null;
    }
    if (_signatures.isEmpty) {
      _error = 'Añade al menos una firma antes de exportar.';
      _notify();
      return null;
    }
    if (_saving) {
      _error = 'Espera a que termine la firma actual.';
      _notify();
      return null;
    }
    if (_exporting) {
      _error = 'Ya hay una exportación en curso.';
      _notify();
      return null;
    }

    _exporting = true;
    _error = null;
    _notify();

    SignedPdfExportResult? result;
    try {
      result = await _exportService.exportSignedPdf(
        book: book,
        signatures: _signatures,
      );
      final file = File(result.pdfPath);
      final baseTitle = book.title
          .replaceAll(RegExp(r'\s*\(firmado\)\s*$'), '')
          .trim();
      final tags = {
        for (final tag in book.tags) tag,
        'firmado',
      }.toList(growable: false);

      await _datasource.insertBook(
        Book(
          title: '$baseTitle (firmado)',
          filePath: result.pdfPath,
          fileSize: await file.length(),
          addedAt: DateTime.now(),
          collectionId: book.collectionId,
          tags: tags,
        ),
      );
      return result;
    } catch (_) {
      // Limpia artefactos huérfanos si el PDF se escribió pero falló el alta.
      final orphan = result;
      if (orphan != null) {
        try {
          final pdf = File(orphan.pdfPath);
          if (await pdf.exists()) await pdf.delete();
          final manifest = File(orphan.manifestPath);
          if (await manifest.exists()) await manifest.delete();
        } catch (_) {}
      }
      _error = 'No se pudo exportar el PDF firmado.';
      return null;
    } finally {
      _exporting = false;
      _notify();
    }
  }

  void clearError() {
    if (_error == null) return;
    _error = null;
    _notify();
  }
}
