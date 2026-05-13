import 'package:sqlite3/sqlite3.dart' as sqlite;

class SqliteDatabase {
  SqliteDatabase._(this.database);

  final sqlite.Database database;

  factory SqliteDatabase.open(String databasePath) {
    final database = sqlite.sqlite3.open(databasePath);
    database.execute('PRAGMA foreign_keys = ON;');
    database.execute('''
      CREATE TABLE IF NOT EXISTS receipts (
        id TEXT PRIMARY KEY,
        created_at TEXT NOT NULL,
        status TEXT NOT NULL,
        extract_request_id TEXT NOT NULL
      );
    ''');
    database.execute('''
      CREATE TABLE IF NOT EXISTS receipt_images (
        receipt_id TEXT PRIMARY KEY,
        original_file_name TEXT NOT NULL,
        mime_type TEXT NOT NULL,
        storage_path TEXT NOT NULL,
        sha256 TEXT NOT NULL,
        size_bytes INTEGER NOT NULL,
        FOREIGN KEY (receipt_id) REFERENCES receipts(id) ON DELETE CASCADE
      );
    ''');
    database.execute('''
      CREATE TABLE IF NOT EXISTS receipt_extractions (
        receipt_id TEXT PRIMARY KEY,
        raw_text TEXT NOT NULL,
        ocr_json TEXT NOT NULL,
        structured_json TEXT NOT NULL DEFAULT '{}',
        metadata_json TEXT NOT NULL,
        FOREIGN KEY (receipt_id) REFERENCES receipts(id) ON DELETE CASCADE
      );
    ''');
    database.execute('''
      CREATE TABLE IF NOT EXISTS receipt_warnings (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        receipt_id TEXT NOT NULL,
        warning_json TEXT NOT NULL,
        FOREIGN KEY (receipt_id) REFERENCES receipts(id) ON DELETE CASCADE
      );
    ''');

    final receiptExtractionColumns = database
        .select('PRAGMA table_info(receipt_extractions);')
        .map((row) => row['name'] as String)
        .toSet();
    if (!receiptExtractionColumns.contains('request_id')) {
      database.execute('ALTER TABLE receipt_extractions ADD COLUMN request_id TEXT;');
      database.execute('UPDATE receipt_extractions SET request_id = (SELECT extract_request_id FROM receipts WHERE receipts.id = receipt_extractions.receipt_id);');
    }
    if (!receiptExtractionColumns.contains('structured_json')) {
      database.execute(
        "ALTER TABLE receipt_extractions ADD COLUMN structured_json TEXT NOT NULL DEFAULT '{}';",
      );
    }

    final receiptWarningColumns = database
        .select('PRAGMA table_info(receipt_warnings);')
        .map((row) => row['name'] as String)
        .toSet();
    if (!receiptWarningColumns.contains('request_id')) {
      database.execute('ALTER TABLE receipt_warnings ADD COLUMN request_id TEXT;');
      database.execute('UPDATE receipt_warnings SET request_id = (SELECT extract_request_id FROM receipts WHERE receipts.id = receipt_warnings.receipt_id);');
    }

    return SqliteDatabase._(database);
  }
}
