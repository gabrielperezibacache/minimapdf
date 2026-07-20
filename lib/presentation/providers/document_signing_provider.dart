import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../../core/utils/library_file_coordinator.dart';
import '../../data/datasources/library_local_datasource.dart';
import '../../data/models/book.dart';
import '../../data/models/document_signature.dart';
import '../../data/models/signature_role.dart';
import '../../data/models/signature_template.dart';
import '../../data/models/signature_type.dart';
import '../../domain/electronic_signature_service.dart';
import '../../domain/signed_pdf_export_service.dart';
import '../../l10n/app_localizations.dart';
import '../../l10n/app_message_keys.dart';

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
    if (_disposed) return;
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
      if (_disposed) return;
      final templates = await _datasource.listSignatureTemplates();
      if (_disposed || generation != _loadGeneration || _bookId != bookId) {
        return;
      }
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
      if (_disposed || generation != _loadGeneration || _bookId != bookId) {
        return;
      }
      _error = AppMessageKeys.signaturesLoadFailed;
      // Conserva la lista previa si ya había firmas en memoria.
    } finally {
      if (!_disposed && generation == _loadGeneration) {
        _loading = false;
        _notify();
      }
    }
  }

  /// Compatibilidad con llamadas antiguas por id.
  Future<void> loadForBookId(int bookId) async {
    if (_disposed) return;
    final book = await _datasource.findBookById(bookId);
    if (_disposed) return;
    if (book != null) {
      await loadForBook(book);
      return;
    }

    // Libro ausente en DB: carga firmas huérfanas con las mismas barreras
    // de generación que [loadForBook] para no pisar mutaciones locales.
    _book = null;
    _bookId = bookId;
    final generation = ++_loadGeneration;
    final dataGenerationAtStart = _dataGeneration;
    _loading = true;
    _error = null;
    _notify();
    try {
      final loaded = await _datasource.listSignatures(bookId);
      if (_disposed) return;
      final templates = await _datasource.listSignatureTemplates();
      if (_disposed || generation != _loadGeneration || _bookId != bookId) {
        return;
      }
      if (_saving || dataGenerationAtStart != _dataGeneration) {
        if (dataGenerationAtStart == _dataGeneration) {
          _templates = templates;
        }
        return;
      }
      _signatures = loaded;
      _templates = templates;
    } catch (_) {
      if (_disposed || generation != _loadGeneration || _bookId != bookId) {
        return;
      }
      _error = AppMessageKeys.signaturesLoadFailed;
    } finally {
      if (!_disposed && generation == _loadGeneration) {
        _loading = false;
        _notify();
      }
    }
  }

  void beginPlacementMode() {
    if (_disposed || _loading || _saving || _exporting) return;
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
    if (!offsetX.isFinite || !offsetY.isFinite) return;
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
    if (_disposed) return null;
    final bookId = _bookId;
    if (bookId == null) {
      _error = AppMessageKeys.documentUnavailableSign;
      _notify();
      return null;
    }
    if (_loading) {
      _error = AppMessageKeys.waitForSignaturesLoad;
      _notify();
      return null;
    }
    if (_saving) {
      _error = AppMessageKeys.signatureBusy;
      _notify();
      return null;
    }
    if (_exporting) {
      _error = AppMessageKeys.waitForExport;
      _notify();
      return null;
    }

    _saving = true;
    _error = null;
    _notify();

    try {
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

      // signingOrder provisional; la DB asigna el definitivo en la transacción.
      final signature = _signatureService.signDocument(
        bookId: bookId,
        pageNumber: pageNumber,
        draft: withPlacement,
        existingOnPage: signaturesForPage(pageNumber),
        signingOrder: 1,
      );
      final saved =
          await _datasource.insertSignatureWithNextOrder(signature);
      if (_disposed) return saved;
      _dataGeneration++;

      // Recarga desde DB: evita huérfanos si loadForBook quedó a medias.
      try {
        final loaded = await _datasource.listSignatures(bookId);
        if (!_disposed) {
          _signatures = loaded;
        }
      } catch (_) {
        if (!_disposed) {
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
        }
      }
      _pendingOffsetX = null;
      _pendingOffsetY = null;

      if (draft.saveAsTemplate) {
        try {
          await _saveTemplateFromDraft(draft);
        } catch (_) {
          if (!_disposed) {
            _error = AppMessageKeys.templatePartial;
          }
        }
      }

      return saved;
    } on SignatureValidationException catch (error) {
      // Clave de l10n; la UI resuelve con AppLocalizations.message.
      if (!_disposed) _error = error.message;
      return null;
    } catch (_) {
      if (!_disposed) _error = AppMessageKeys.signatureSaveFailed;
      return null;
    } finally {
      _saving = false;
      _notify();
    }
  }

  Future<void> _saveTemplateFromDraft(SignatureDraft draft) async {
    if (_disposed) return;
    final requestedName = draft.templateName?.trim() ?? '';
    final name = _signatureService.normalizePersonText(
      requestedName.isNotEmpty ? requestedName : draft.signerName,
    );
    if (name.isEmpty) {
      throw StateError(AppMessageKeys.indicateTemplateName);
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
    if (_disposed) return;
    _dataGeneration++;
    _templates = [saved, ..._templates];
  }

  Future<void> reloadTemplates() async {
    if (_disposed) return;
    try {
      final templates = await _datasource.listSignatureTemplates();
      if (_disposed) return;
      _templates = templates;
      _dataGeneration++;
      _error = null;
      _notify();
    } catch (_) {
      if (_disposed) return;
      _error = AppMessageKeys.templatesLoadFailed;
      _notify();
    }
  }

  Future<bool> deleteTemplate(SignatureTemplate template) async {
    if (_disposed) return false;
    final id = template.id;
    if (id == null) return false;
    try {
      await _datasource.removeSignatureTemplate(id);
      if (_disposed) return false;
      _dataGeneration++;
      _templates = [
        for (final item in _templates)
          if (item.id != id) item,
      ];
      _error = null;
      _notify();
      return true;
    } catch (_) {
      if (_disposed) return false;
      _error = AppMessageKeys.templateDeleteFailed;
      _notify();
      return false;
    }
  }

  /// Actualiza la posición relativa del sello en la página.
  ///
  /// Devuelve `true` si se aplicó un cambio (aunque el write aún esté en curso).
  Future<bool> moveSignature({
    required DocumentSignature signature,
    required double offsetX,
    required double offsetY,
  }) async {
    if (_disposed) return false;
    if (_exporting) {
      _error = AppMessageKeys.waitForExport;
      _notify();
      return false;
    }
    final id = signature.id;
    if (id == null) return false;
    if (!offsetX.isFinite || !offsetY.isFinite) return false;

    final nextX = offsetX.clamp(0.0, 1.0).toDouble();
    final nextY = offsetY.clamp(0.0, 1.0).toDouble();
    if ((signature.offsetX - nextX).abs() < 0.001 &&
        (signature.offsetY - nextY).abs() < 0.001) {
      return false;
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
      // Solo el move más reciente reescribe hasta estabilizar el offset.
      if (generation != _moveGeneration) return true;
      while (!_disposed) {
        DocumentSignature? latest;
        for (final item in _signatures) {
          if (item.id == id) {
            latest = item;
            break;
          }
        }
        if (latest == null) return true;
        final snapshot = latest;
        await _datasource.saveSignature(snapshot);
        if (_disposed) return true;
        if (generation != _moveGeneration) return true;
        DocumentSignature? after;
        for (final item in _signatures) {
          if (item.id == id) {
            after = item;
            break;
          }
        }
        if (after == null) return true;
        if ((after.offsetX - snapshot.offsetX).abs() < 0.0001 &&
            (after.offsetY - snapshot.offsetY).abs() < 0.0001) {
          return true;
        }
      }
    } catch (_) {
      if (_disposed || generation != _moveGeneration) return false;
      _error = AppMessageKeys.signatureMoveFailed;
      // Revierte el offset optimista; no dejar sellos "fantasma" para export.
      _signatures = [
        for (final item in _signatures)
          if (item.id == id) signature else item,
      ];
      _notify();
      final book = _book;
      if (book != null) {
        try {
          await loadForBook(book);
        } catch (_) {
          // El error de move ya está expuesto; el reload es best-effort.
        }
      }
      return false;
    }
    return false;
  }

  Future<bool> deleteSignature(DocumentSignature signature) async {
    if (_disposed) return false;
    if (_exporting) {
      _error = AppMessageKeys.waitForExport;
      _notify();
      return false;
    }
    final bookId = _bookId;
    final id = signature.id;
    if (bookId == null || id == null) return false;

    try {
      await _datasource.removeSignature(id);
      if (_disposed) return false;
      _dataGeneration++;
      _signatures = [
        for (final item in _signatures)
          if (item.id != id) item,
      ];
      _notify();
      return true;
    } catch (_) {
      if (_disposed) return false;
      _error = AppMessageKeys.deleteSignatureFailed;
      _notify();
      return false;
    }
  }

  /// Exporta PDF firmado (sellos aplanados) + manifiesto SHA-256 e importa
  /// la copia a la biblioteca.
  ///
  /// [signedMarker] y [roleLabelOf] localizan el sufijo del título/archivo y
  /// las etiquetas de rol pintadas en el PDF.
  Future<SignedPdfExportResult?> exportSignedPdf({
    String signedMarker = 'signed',
    String Function(SignatureRole role)? roleLabelOf,
  }) async {
    if (_disposed) return null;
    final book = _book;
    if (book == null) {
      _error = AppMessageKeys.documentUnavailable;
      _notify();
      return null;
    }
    if (_signatures.isEmpty) {
      _error = AppMessageKeys.needSignature;
      _notify();
      return null;
    }
    if (_placementMode) {
      _error = AppMessageKeys.cancelPlacement;
      _notify();
      return null;
    }
    if (_saving) {
      _error = AppMessageKeys.waitForSigning;
      _notify();
      return null;
    }
    if (_exporting) {
      _error = AppMessageKeys.exportInProgress;
      _notify();
      return null;
    }

    _exporting = true;
    _error = null;
    _notify();

    // Congela firmas al inicio para que move/delete no alteren el PDF exportado.
    final signaturesSnapshot = List<DocumentSignature>.from(_signatures);
    SignedPdfExportResult? result;
    // Se asigna antes de insertBook: si el alta falla, el catch limpia el disco.
    SignedPdfExportResult? writtenArtifacts;
    try {
      // Serializa con import/descargas y reserva nombres de DB para evitar
      // colisiones y borrados cruzados del PDF exportado.
      result = await LibraryFileCoordinator.runExclusive(() async {
        SignedPdfExportResult? exported;
        try {
          final reserved = await _datasource.listReservedLibraryBasenames();
          final marker =
              signedMarker.trim().isEmpty ? 'signed' : signedMarker.trim();
          exported = await _exportService.exportSignedPdf(
            book: book,
            signatures: signaturesSnapshot,
            reservedBasenames: reserved,
            signedMarker: marker,
            roleLabelOf: roleLabelOf,
          );
          writtenArtifacts = exported;
          final file = File(exported.pdfPath);
          final baseTitle = AppLocalizations.stripSignedMarker(book.title);
          final tags = {
            for (final tag in book.tags) tag,
            marker,
          }.toList(growable: false);

          // Evita FK rota si la colección se borró mientras el libro seguía abierto.
          var collectionId = book.collectionId;
          if (collectionId != null) {
            final found = await _datasource.findCollectionById(collectionId);
            collectionId = found?.id;
          }

          await _datasource.insertBook(
            Book(
              title: '$baseTitle ($marker)',
              filePath: exported.pdfPath,
              fileSize: await file.length(),
              addedAt: DateTime.now(),
              collectionId: collectionId,
              tags: tags,
            ),
          );
          return exported;
        } catch (_) {
          // Limpia dentro del lock para no borrar un import concurrente.
          final orphan = exported ?? writtenArtifacts;
          if (orphan != null) {
            try {
              final pdf = File(orphan.pdfPath);
              if (await pdf.exists()) await pdf.delete();
              final manifest = File(orphan.manifestPath);
              if (await manifest.exists()) await manifest.delete();
            } catch (_) {}
            writtenArtifacts = null;
          }
          rethrow;
        }
      });
      writtenArtifacts = null;
      return result;
    } catch (_) {
      _error = AppMessageKeys.exportSignedFailed;
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
