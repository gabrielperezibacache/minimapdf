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
  Future<Database>? _opening;

  Database get database {
    final db = _db;
    if (db == null) {
      throw StateError(
        'AppDatabase is not initialized. Call open() first.',
      );
    }
    return db;
  }

  bool get isOpen => _db != null && _db!.isOpen;

  Future<Database> open() async {
    if (_db != null && _db!.isOpen) return _db!;
    final inFlight = _opening;
    if (inFlight != null) return inFlight;

    final future = _openOnce();
    _opening = future;
    try {
      return await future;
    } finally {
      if (identical(_opening, future)) {
        _opening = null;
      }
    }
  }

  Future<Database> _openOnce() async {
    if (_db != null && _db!.isOpen) return _db!;

    final factory = customFactory ?? databaseFactory;
    final path = databasePath ?? await _defaultPath();

    final db = await factory.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: DatabaseConfig.databaseVersion,
        onConfigure: (database) async {
          await database.execute('PRAGMA foreign_keys = ON');
        },
        onCreate: (database, version) async {
          await _createSchema(database);
        },
        onUpgrade: (database, oldVersion, newVersion) async {
          if (oldVersion < 2) {
            await _createSignaturesTable(database);
          }
          if (oldVersion < 3) {
            await _upgradeSignaturesToV3(database);
            await _createSignatureTemplatesTable(database);
          }
          if (oldVersion < 4) {
            await _createPageAnnotationsTable(database);
          }
          if (oldVersion < 5) {
            await _upgradePageAnnotationsToV5(database);
          }
        },
      ),
    );
    _db = db;
    return db;
  }

  Future<void> close() async {
    final opening = _opening;
    if (opening != null) {
      try {
        await opening;
      } catch (_) {
        // Ignorar fallo de apertura en curso al cerrar.
      }
    }
    final db = _db;
    _db = null;
    _opening = null;
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

    await _createSignaturesTable(db);
    await _createSignatureTemplatesTable(db);
    await _createPageAnnotationsTable(db);
  }

  Future<void> _createSignaturesTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS ${DatabaseConfig.tableSignatures} (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        book_id INTEGER NOT NULL,
        page_number INTEGER NOT NULL,
        type TEXT NOT NULL,
        signer_name TEXT NOT NULL,
        typed_text TEXT,
        ink_json TEXT,
        reason TEXT,
        role TEXT NOT NULL DEFAULT 'signer',
        signing_order INTEGER NOT NULL DEFAULT 1,
        offset_x REAL NOT NULL DEFAULT 0.58,
        offset_y REAL NOT NULL DEFAULT 0.70,
        signed_at TEXT NOT NULL,
        FOREIGN KEY (book_id)
          REFERENCES ${DatabaseConfig.tableBooks} (id)
          ON DELETE CASCADE
      )
    ''');

    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_signatures_book_id '
      'ON ${DatabaseConfig.tableSignatures} (book_id)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_signatures_book_page '
      'ON ${DatabaseConfig.tableSignatures} (book_id, page_number)',
    );
  }

  Future<void> _upgradeSignaturesToV3(Database db) async {
    await _createSignaturesTable(db);
    final columns = await db.rawQuery(
      'PRAGMA table_info(${DatabaseConfig.tableSignatures})',
    );
    final names = columns.map((row) => row['name'] as String).toSet();
    if (!names.contains('role')) {
      await db.execute(
        'ALTER TABLE ${DatabaseConfig.tableSignatures} '
        "ADD COLUMN role TEXT NOT NULL DEFAULT 'signer'",
      );
    }
    final addedOrder = !names.contains('signing_order');
    if (addedOrder) {
      await db.execute(
        'ALTER TABLE ${DatabaseConfig.tableSignatures} '
        'ADD COLUMN signing_order INTEGER NOT NULL DEFAULT 1',
      );
    }
    // Backfill: filas migradas quedan en 1; reasigna por signed_at/id.
    if (addedOrder) {
      await db.execute('''
        UPDATE ${DatabaseConfig.tableSignatures}
        SET signing_order = (
          SELECT COUNT(*)
          FROM ${DatabaseConfig.tableSignatures} AS sibling
          WHERE sibling.book_id = ${DatabaseConfig.tableSignatures}.book_id
            AND (
              sibling.signed_at < ${DatabaseConfig.tableSignatures}.signed_at
              OR (
                sibling.signed_at = ${DatabaseConfig.tableSignatures}.signed_at
                AND sibling.id <= ${DatabaseConfig.tableSignatures}.id
              )
            )
        )
      ''');
    }
  }

  Future<void> _createSignatureTemplatesTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS ${DatabaseConfig.tableSignatureTemplates} (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        type TEXT NOT NULL,
        signer_name TEXT NOT NULL,
        typed_text TEXT,
        ink_json TEXT,
        role TEXT NOT NULL DEFAULT 'signer',
        created_at TEXT NOT NULL
      )
    ''');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_signature_templates_created '
      'ON ${DatabaseConfig.tableSignatureTemplates} (created_at DESC)',
    );
  }

  Future<void> _createPageAnnotationsTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS ${DatabaseConfig.tablePageAnnotations} (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        book_id INTEGER NOT NULL,
        page_number INTEGER NOT NULL,
        type TEXT NOT NULL,
        text TEXT,
        x REAL NOT NULL,
        y REAL NOT NULL,
        width REAL NOT NULL,
        height REAL NOT NULL,
        ink_json TEXT,
        color_value INTEGER NOT NULL,
        created_at TEXT NOT NULL,
        FOREIGN KEY (book_id)
          REFERENCES ${DatabaseConfig.tableBooks} (id)
          ON DELETE CASCADE
      )
    ''');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_page_annotations_book_id '
      'ON ${DatabaseConfig.tablePageAnnotations} (book_id)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_page_annotations_book_page '
      'ON ${DatabaseConfig.tablePageAnnotations} (book_id, page_number)',
    );
  }

  Future<void> _upgradePageAnnotationsToV5(Database db) async {
    await _createPageAnnotationsTable(db);
    final columns = await db.rawQuery(
      'PRAGMA table_info(${DatabaseConfig.tablePageAnnotations})',
    );
    final names = columns.map((row) => row['name'] as String).toSet();
    if (!names.contains('ink_json')) {
      await db.execute(
        'ALTER TABLE ${DatabaseConfig.tablePageAnnotations} '
        'ADD COLUMN ink_json TEXT',
      );
    }
  }
}
