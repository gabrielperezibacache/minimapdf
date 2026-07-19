/// Configuración y nombres de tablas/índices de la base local (Sqflite).
abstract final class DatabaseConfig {
  static const String databaseName = 'minimal_pdf.db';
  static const int databaseVersion = 1;

  static const String tableBooks = 'books';
  static const String tableCollections = 'collections';
  static const String tableBookmarks = 'bookmarks';
}
