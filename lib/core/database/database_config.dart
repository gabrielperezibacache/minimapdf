/// Configuración y nombres de tablas/índices de la base local (Sqflite).
abstract final class DatabaseConfig {
  static const String databaseName = 'minimal_pdf.db';
  static const int databaseVersion = 3;

  static const String tableBooks = 'books';
  static const String tableCollections = 'collections';
  static const String tableBookmarks = 'bookmarks';
  static const String tableSignatures = 'document_signatures';
  static const String tableSignatureTemplates = 'signature_templates';
}
