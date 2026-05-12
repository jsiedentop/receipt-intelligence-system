import 'dart:convert';

import 'package:ris_core/ris_core.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite;

import '../../domain/exceptions/app_exceptions.dart';
import '../../domain/models/receipt.dart';
import '../../domain/repositories/receipt_repository.dart';

class SqliteReceiptRepository implements ReceiptRepository {
  const SqliteReceiptRepository(this._database);

  final sqlite.Database _database;

  @override
  Future<void> create(Receipt receipt) async {
    try {
      _database.execute('BEGIN;');
      _database.execute(
        'INSERT INTO receipts (id, created_at, status, extract_request_id) VALUES (?, ?, ?, ?);',
        [
          receipt.id.value,
          receipt.createdAt.toIso8601String(),
          receipt.status.name,
          receipt.extractRequestId.value,
        ],
      );
      _database.execute(
        '''
        INSERT INTO receipt_images (
          receipt_id,
          original_file_name,
          mime_type,
          storage_path,
          sha256,
          size_bytes
        ) VALUES (?, ?, ?, ?, ?, ?);
        ''',
        [
          receipt.id.value,
          receipt.image.originalFileName,
          receipt.image.mimeType,
          receipt.image.storagePath,
          receipt.image.sha256,
          receipt.image.sizeBytes,
        ],
      );
      if (receipt.extraction case final extraction?) {
        _insertExtraction(
          receiptId: receipt.id,
          requestId: receipt.extractRequestId,
          extraction: extraction,
        );
      }
      _database.execute('COMMIT;');
    } catch (error) {
      _safeRollback();
      throw PersistenceException('Failed to persist receipt.', cause: error);
    }
  }

  @override
  Future<Receipt> getById(ReceiptId receiptId) async {
    try {
      final row = _selectReceiptRow(receiptId);

      final extraction = _selectExtraction(receiptId);

      return Receipt(
        id: ReceiptId(row['id'] as String),
        createdAt: DateTime.parse(row['created_at'] as String),
        status: ReceiptStatus.values.byName(row['status'] as String),
        image: StoredReceiptImage(
          originalFileName: row['original_file_name'] as String,
          mimeType: row['mime_type'] as String,
          storagePath: row['storage_path'] as String,
          sha256: row['sha256'] as String,
          sizeBytes: row['size_bytes'] as int,
        ),
        extractRequestId: ExtractRequestId(row['extract_request_id'] as String),
        extraction: extraction,
      );
    } on AppException {
      rethrow;
    } catch (error) {
      throw PersistenceException('Failed to load receipt.', cause: error);
    }
  }

  @override
  Future<void> updateStatus({
    required ReceiptId receiptId,
    required ReceiptStatus status,
  }) async {
    _updateReceipt(
      receiptId: receiptId,
      status: status,
    );
  }

  @override
  Future<void> replacePendingExtraction({
    required ReceiptId receiptId,
    required ExtractRequestId requestId,
  }) async {
    try {
      _database.execute('BEGIN;');
      _deleteExtractionRows(receiptId);
      _database.execute(
        'UPDATE receipts SET status = ?, extract_request_id = ? WHERE id = ?;',
        [ReceiptStatus.pending.name, requestId.value, receiptId.value],
      );
      _database.execute('COMMIT;');
    } catch (error) {
      _safeRollback();
      throw PersistenceException('Failed to replace receipt extraction.', cause: error);
    }
  }

  @override
  Future<void> saveProcessedExtraction({
    required ReceiptId receiptId,
    required ExtractRequestId requestId,
    required ExtractResponse extraction,
  }) async {
    try {
      _database.execute('BEGIN;');
      _deleteExtractionRows(receiptId);
      _insertExtraction(
        receiptId: receiptId,
        requestId: requestId,
        extraction: ReceiptExtraction(
          requestId: extraction.requestId,
          rawText: extraction.ocr.rawText,
          ocrData: extraction.ocr.toJson(),
          metadata: extraction.metadata.toJson(),
          warnings: extraction.warnings,
        ),
      );
      _database.execute(
        'UPDATE receipts SET status = ?, extract_request_id = ? WHERE id = ?;',
        [ReceiptStatus.processed.name, requestId.value, receiptId.value],
      );
      _database.execute('COMMIT;');
    } catch (error) {
      _safeRollback();
      throw PersistenceException('Failed to persist extracted receipt.', cause: error);
    }
  }

  @override
  Future<void> clearExtraction({
    required ReceiptId receiptId,
    required ExtractRequestId requestId,
    required ReceiptStatus status,
  }) async {
    try {
      _database.execute('BEGIN;');
      _deleteExtractionRows(receiptId);
      _database.execute(
        'UPDATE receipts SET status = ?, extract_request_id = ? WHERE id = ?;',
        [status.name, requestId.value, receiptId.value],
      );
      _database.execute('COMMIT;');
    } catch (error) {
      _safeRollback();
      throw PersistenceException('Failed to clear receipt extraction.', cause: error);
    }
  }

  @override
  Future<List<Receipt>> listByStatuses(List<ReceiptStatus> statuses) async {
    if (statuses.isEmpty) {
      return const <Receipt>[];
    }

    try {
      final placeholders = List.filled(statuses.length, '?').join(', ');
      final rows = _database.select(
        '''
        SELECT
          receipts.id,
          receipts.created_at,
          receipts.status,
          receipts.extract_request_id,
          receipt_images.original_file_name,
          receipt_images.mime_type,
          receipt_images.storage_path,
          receipt_images.sha256,
          receipt_images.size_bytes
        FROM receipts
        INNER JOIN receipt_images ON receipt_images.receipt_id = receipts.id
        WHERE receipts.status IN ($placeholders)
        ORDER BY receipts.created_at ASC;
        ''',
        statuses.map((status) => status.name).toList(growable: false),
      );

      return rows
          .map(
            (row) => Receipt(
              id: ReceiptId(row['id'] as String),
              createdAt: DateTime.parse(row['created_at'] as String),
              status: ReceiptStatus.values.byName(row['status'] as String),
              image: StoredReceiptImage(
                originalFileName: row['original_file_name'] as String,
                mimeType: row['mime_type'] as String,
                storagePath: row['storage_path'] as String,
                sha256: row['sha256'] as String,
                sizeBytes: row['size_bytes'] as int,
              ),
              extractRequestId: ExtractRequestId(
                row['extract_request_id'] as String,
              ),
              extraction: null,
            ),
          )
          .toList(growable: false);
    } on AppException {
      rethrow;
    } catch (error) {
      throw PersistenceException('Failed to load receipts.', cause: error);
    }
  }

  @override
  Future<List<Receipt>> list({required int limit, required int offset}) async {
    try {
      final rows = _database.select(
        '''
        SELECT
          receipts.id,
          receipts.created_at,
          receipts.status,
          receipts.extract_request_id,
          receipt_images.original_file_name,
          receipt_images.mime_type,
          receipt_images.storage_path,
          receipt_images.sha256,
          receipt_images.size_bytes
        FROM receipts
        INNER JOIN receipt_images ON receipt_images.receipt_id = receipts.id
        ORDER BY receipts.created_at DESC, receipts.id DESC
        LIMIT ? OFFSET ?;
        ''',
        [limit, offset],
      );

      return rows
          .map(
            (row) {
              final receiptId = ReceiptId(row['id'] as String);
              return Receipt(
                id: receiptId,
                createdAt: DateTime.parse(row['created_at'] as String),
                status: ReceiptStatus.values.byName(row['status'] as String),
                image: StoredReceiptImage(
                  originalFileName: row['original_file_name'] as String,
                  mimeType: row['mime_type'] as String,
                  storagePath: row['storage_path'] as String,
                  sha256: row['sha256'] as String,
                  sizeBytes: row['size_bytes'] as int,
                ),
                extractRequestId: ExtractRequestId(
                  row['extract_request_id'] as String,
                ),
                extraction: _selectExtraction(receiptId),
              );
            },
          )
          .toList(growable: false);
    } on AppException {
      rethrow;
    } catch (error) {
      throw PersistenceException('Failed to load receipts.', cause: error);
    }
  }

  @override
  Future<void> delete(ReceiptId receiptId) async {
    try {
      final rows = _database.select(
        'SELECT id FROM receipts WHERE id = ?;',
        [receiptId.value],
      );
      if (rows.isEmpty) {
        throw ReceiptNotFoundException('Receipt "${receiptId.value}" was not found.');
      }

      _database.execute('DELETE FROM receipts WHERE id = ?;', [receiptId.value]);
    } on AppException {
      rethrow;
    } catch (error) {
      throw PersistenceException('Failed to delete receipt.', cause: error);
    }
  }

  sqlite.Row _selectReceiptRow(ReceiptId receiptId) {
    final rows = _database.select(
      '''
      SELECT
        receipts.id,
        receipts.created_at,
        receipts.status,
        receipts.extract_request_id,
        receipt_images.original_file_name,
        receipt_images.mime_type,
        receipt_images.storage_path,
        receipt_images.sha256,
        receipt_images.size_bytes
      FROM receipts
      INNER JOIN receipt_images ON receipt_images.receipt_id = receipts.id
      WHERE receipts.id = ?;
      ''',
      [receiptId.value],
    );

    if (rows.isEmpty) {
      throw ReceiptNotFoundException('Receipt "${receiptId.value}" was not found.');
    }

    return rows.first;
  }

  ReceiptExtraction? _selectExtraction(ReceiptId receiptId) {
    final rows = _database.select(
      '''
      SELECT request_id, raw_text, ocr_json, metadata_json
      FROM receipt_extractions
      WHERE receipt_id = ?;
      ''',
      [receiptId.value],
    );
    if (rows.isEmpty) {
      return null;
    }

    final warnings = _database
        .select(
          'SELECT warning_json FROM receipt_warnings WHERE receipt_id = ? ORDER BY id ASC;',
          [receiptId.value],
        )
        .map((row) => jsonDecode(row['warning_json'] as String))
        .toList(growable: false);

    final row = rows.first;
    return ReceiptExtraction(
      requestId: ExtractRequestId(row['request_id'] as String),
      rawText: row['raw_text'] as String,
      ocrData: _decodeJsonMap(row['ocr_json'] as String),
      metadata: _decodeJsonMap(row['metadata_json'] as String),
      warnings: warnings,
    );
  }

  void _updateReceipt({
    required ReceiptId receiptId,
    required ReceiptStatus status,
  }) {
    try {
      _database.execute(
        'UPDATE receipts SET status = ? WHERE id = ?;',
        [status.name, receiptId.value],
      );
    } catch (error) {
      throw PersistenceException('Failed to update receipt status.', cause: error);
    }
  }

  void _deleteExtractionRows(ReceiptId receiptId) {
    _database.execute(
      'DELETE FROM receipt_warnings WHERE receipt_id = ?;',
      [receiptId.value],
    );
    _database.execute(
      'DELETE FROM receipt_extractions WHERE receipt_id = ?;',
      [receiptId.value],
    );
  }

  void _insertExtraction({
    required ReceiptId receiptId,
    required ExtractRequestId requestId,
    required ReceiptExtraction extraction,
  }) {
    _database.execute(
      '''
      INSERT INTO receipt_extractions (
        receipt_id,
        request_id,
        raw_text,
        ocr_json,
        metadata_json
      ) VALUES (?, ?, ?, ?, ?);
      ''',
      [
        receiptId.value,
        requestId.value,
        extraction.rawText,
        jsonEncode(extraction.ocrData),
        jsonEncode(extraction.metadata),
      ],
    );
    for (final warning in extraction.warnings) {
      _database.execute(
        'INSERT INTO receipt_warnings (receipt_id, request_id, warning_json) VALUES (?, ?, ?);',
        [receiptId.value, requestId.value, jsonEncode(warning)],
      );
    }
  }

  void _safeRollback() {
    try {
      _database.execute('ROLLBACK;');
    } catch (_) {
      // Ignore rollback errors.
    }
  }
}

Map<String, dynamic> _decodeJsonMap(String value) {
  final decoded = jsonDecode(value);
  if (decoded is Map<String, dynamic>) {
    return decoded;
  }

  if (decoded is Map) {
    return decoded.map(
      (key, entryValue) => MapEntry(key.toString(), entryValue),
    );
  }

  throw const FormatException('Expected JSON object.');
}
