/// Configuración y nombres de tablas/índices de la base local (Sqflite).
abstract final class DatabaseConfig {
  static const String databaseName = 'minimal_pdf.db';

  /// v1: books / collections / bookmarks
  /// v2: document_signatures
  /// v3: roles/orden en firmas + signature_templates
  /// v4: page_annotations (marcados, subrayados, notas, comentarios)
  static const int databaseVersion = 4;

  static const String tableBooks = 'books';
  static const String tableCollections = 'collections';
  static const String tableBookmarks = 'bookmarks';
  static const String tableSignatures = 'document_signatures';
  static const String tableSignatureTemplates = 'signature_templates';
  static const String tablePageAnnotations = 'page_annotations';
}
