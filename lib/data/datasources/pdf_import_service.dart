import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;

import '../../core/utils/app_paths.dart';
import '../../core/utils/file_name_sanitizer.dart';
import '../models/book.dart';
import 'library_local_datasource.dart';

/// PDF seleccionado desde el dispositivo (antes de copiarlo a la app).
class PickedPdfFile {
  const PickedPdfFile({
    required this.sourcePath,
    required this.displayName,
    required this.fileSize,
  });

  final String sourcePath;
  final String displayName;
  final int fileSize;
}

typedef PdfFilePicker = Future<PickedPdfFile?> Function();

/// Importa PDFs locales al directorio de documentos de la app y a la DB.
class PdfImportService {
  PdfImportService(
    this._datasource, {
    PdfFilePicker? picker,
    Future<Directory> Function()? documentsDirectory,
  })  : _picker = picker ?? _defaultPicker,
        _documentsDirectory =
            documentsDirectory ?? AppPaths.documentsDirectory;

  final LibraryLocalDatasource _datasource;
  final PdfFilePicker _picker;
  final Future<Directory> Function() _documentsDirectory;

  static Future<PickedPdfFile?> _defaultPicker() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['pdf'],
      allowMultiple: false,
      withData: false,
    );

    if (result == null || result.files.isEmpty) return null;

    final file = result.files.single;
    final path = file.path;
    if (path == null || path.isEmpty) return null;

    return PickedPdfFile(
      sourcePath: path,
      displayName: file.name,
      fileSize: file.size,
    );
  }

  /// Selecciona un PDF, lo copia a documentos de la app y lo registra en la DB.
  Future<Book?> importFromDevice({int? collectionId}) async {
    final picked = await _picker();
    if (picked == null) return null;
    return importPickedFile(picked, collectionId: collectionId);
  }

  Future<Book> importPickedFile(
    PickedPdfFile picked, {
    int? collectionId,
  }) async {
    final docs = await _documentsDirectory();
    final libraryDir = Directory(p.join(docs.path, 'library'));
    if (!await libraryDir.exists()) {
      await libraryDir.create(recursive: true);
    }

    final existing = await libraryDir
        .list()
        .where((entity) => entity is File)
        .map((entity) => p.basename(entity.path).toLowerCase())
        .toSet();

    final sanitized = FileNameSanitizer.sanitize(picked.displayName);
    final unique = FileNameSanitizer.uniqueName(sanitized, existing);
    final destination = p.join(libraryDir.path, unique);

    final source = File(picked.sourcePath);
    if (!await source.exists()) {
      throw StateError('El archivo seleccionado no existe: ${picked.sourcePath}');
    }

    await source.copy(destination);
    final copied = File(destination);
    final size = picked.fileSize > 0 ? picked.fileSize : await copied.length();

    final title = p.basenameWithoutExtension(unique).replaceAll('_', ' ');

    return _datasource.insertBook(
      Book(
        title: title,
        filePath: destination,
        fileSize: size,
        addedAt: DateTime.now(),
        collectionId: collectionId,
      ),
    );
  }
}
