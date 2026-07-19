import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../utils/app_paths.dart';
import 'database_config.dart';

/// Abre y mantiene la conexión Sqflite de Minimal PDF.
///
/// Usa índices en `last_read_at`, `collection_id` y `book_id` para
/// consultas rápidas de recientes, carpetas y marcadores.
class AppDatabase {
  AppDatabase({
    this.customFactory,
    this.databasePath,
  });

  /// Factory inyectable (p. ej. `databaseFactoryFfi` en tests).
  final DatabaseFactory? customFactory;
  final String? databasePath;
  Database? _db;

  Database get database {
    final db = _db;
    if (db == null) {
      throw StateError(
        'AppDatabase no está inicializada. Llama a open() primero.',
      );
    }
    return db;
  }

  bool get isOpen => _db != null && _db!.isOpen;

  Future<Database> open() async {
    if (_db != null && _db!.isOpen) return _db!;

    final factory = customFactory ?? databaseFactory;
    final path = databasePath ?? await _defaultPath();

    _db = await factory.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: DatabaseConfig.databaseVersion,
        onConfigure: (db) async {
          await db.execute('PRAGMA foreign_keys = ON');
        },
        onCreate: (db, version) async {
          await _createSchema(db);
        },
      ),
    );

    return _db!;
  }

  Future<void> close() async {
    final db = _db;
    _db = null;
    if (db != null && db.isOpen) {
      await db.close();
    }
  }

  Future<String> _defaultPath() async {
    final dir = await AppPaths.documentsDirectory();
    return p.join(dir.path, DatabaseConfig.databaseName);
  }

  Future<void> _createSchema(Database db) async {
    await db.execute('''
      CREATE TABLE ${DatabaseConfig.tableCollections} (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        created_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE ${DatabaseConfig.tableBooks} (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT NOT NULL,
        file_path TEXT NOT NULL UNIQUE,
        file_size INTEGER NOT NULL,
        added_at TEXT NOT NULL,
        last_read_at TEXT,
        last_page_read INTEGER NOT NULL DEFAULT 0,
        author TEXT,
        tags TEXT NOT NULL DEFAULT '[]',
        collection_id INTEGER,
        FOREIGN KEY (collection_id)
          REFERENCES ${DatabaseConfig.tableCollections} (id)
          ON DELETE SET NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE ${DatabaseConfig.tableBookmarks} (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        book_id INTEGER NOT NULL,
        page_number INTEGER NOT NULL,
        note_text TEXT,
        created_at TEXT NOT NULL,
        FOREIGN KEY (book_id)
          REFERENCES ${DatabaseConfig.tableBooks} (id)
          ON DELETE CASCADE
      )
    ''');

    await db.execute(
      'CREATE INDEX idx_books_last_read_at '
      'ON ${DatabaseConfig.tableBooks} (last_read_at DESC)',
    );
    await db.execute(
      'CREATE INDEX idx_books_collection_id '
      'ON ${DatabaseConfig.tableBooks} (collection_id)',
    );
    await db.execute(
      'CREATE INDEX idx_books_added_at '
      'ON ${DatabaseConfig.tableBooks} (added_at DESC)',
    );
    await db.execute(
      'CREATE INDEX idx_bookmarks_book_id '
      'ON ${DatabaseConfig.tableBookmarks} (book_id)',
    );
    await db.execute(
      'CREATE UNIQUE INDEX idx_bookmarks_book_page '
      'ON ${DatabaseConfig.tableBookmarks} (book_id, page_number)',
    );
  }
}
