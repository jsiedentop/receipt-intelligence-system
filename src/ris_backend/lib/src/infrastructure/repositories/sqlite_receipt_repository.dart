import 'dart:convert';

import 'package:ris_core/ris_core.dart';
import 'package:nanoid2/nanoid2.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite;

import '../../application/use_cases/receipt_item_validation.dart';
import '../../domain/exceptions/app_exceptions.dart';
import '../../domain/models/merchant.dart';
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
        'INSERT INTO receipts (id, created_at, status, extract_request_id, merchant_id, items_currency) VALUES (?, ?, ?, ?, ?, ?);',
        [
          receipt.id.value,
          receipt.createdAt.toIso8601String(),
          receipt.status.name,
          receipt.extractRequestId.value,
          receipt.merchantId?.value,
          receipt.itemsCurrency,
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
        merchantId: row['merchant_id'] == null
            ? null
            : MerchantId(row['merchant_id'] as String),
        merchant: _selectAssignedMerchant(row['merchant_id'] as String?),
        itemsCurrency: _selectItemsCurrency(receiptId),
        items: _selectItems(receiptId),
        validationWarnings: _selectValidationWarnings(receiptId),
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
    _updateReceipt(receiptId: receiptId, status: status);
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
      throw PersistenceException(
        'Failed to replace receipt extraction.',
        cause: error,
      );
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
      _deleteItemsRows(receiptId);
      _insertExtraction(
        receiptId: receiptId,
        requestId: requestId,
        extraction: ReceiptExtraction(
          requestId: extraction.requestId,
          rawText: extraction.ocr.rawText,
          ocrData: extraction.ocr.toJson(),
          structuredData: extraction.structured.toJson(),
          metadata: extraction.metadata.toJson(),
          warnings: extraction.warnings,
        ),
      );
      final extractedItems = extraction.structured.lineItems;
      final persistedItems =
          extractedItems?.items
              .map(
                (item) => ReceiptItem(
                  id: 'itm_${nanoid(length: 14)}',
                  itemNumber: item.itemNumber,
                  name: item.name,
                  totalPrice: item.totalPrice,
                  quantity: item.quantity,
                  category: item.category == null
                      ? null
                      : ReceiptItemCategory.fromApiValue(item.category!),
                ),
              )
              .toList(growable: false) ??
          const <ReceiptItem>[];
      final validationWarnings = buildReceiptItemValidationWarnings(
        extractedTotalAmount: extractedItems?.totalAmount,
        items: persistedItems,
      );
      _insertItems(
        receiptId: receiptId,
        currency: extractedItems?.currency,
        items: persistedItems,
        validationWarnings: validationWarnings,
      );
      _database.execute(
        'UPDATE receipts SET status = ?, extract_request_id = ?, items_currency = ? WHERE id = ?;',
        [
          ReceiptStatus.processed.name,
          requestId.value,
          extractedItems?.currency,
          receiptId.value,
        ],
      );
      _database.execute('COMMIT;');
    } catch (error) {
      _safeRollback();
      throw PersistenceException(
        'Failed to persist extracted receipt.',
        cause: error,
      );
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
      _deleteItemsRows(receiptId);
      _database.execute(
        'UPDATE receipts SET status = ?, extract_request_id = ?, items_currency = NULL WHERE id = ?;',
        [status.name, requestId.value, receiptId.value],
      );
      _database.execute('COMMIT;');
    } catch (error) {
      _safeRollback();
      throw PersistenceException(
        'Failed to clear receipt extraction.',
        cause: error,
      );
    }
  }

  @override
  Future<List<Receipt>> listByStatuses(List<ReceiptStatus> statuses) async {
    if (statuses.isEmpty) {
      return const <Receipt>[];
    }

    try {
      final placeholders = List.filled(statuses.length, '?').join(', ');
      final rows = _database.select('''
        SELECT
          receipts.id,
          receipts.created_at,
          receipts.status,
          receipts.extract_request_id,
          receipts.merchant_id,
          receipt_images.original_file_name,
          receipt_images.mime_type,
          receipt_images.storage_path,
          receipt_images.sha256,
          receipt_images.size_bytes
        FROM receipts
        INNER JOIN receipt_images ON receipt_images.receipt_id = receipts.id
        WHERE receipts.status IN ($placeholders)
        ORDER BY receipts.created_at ASC;
        ''', statuses.map((status) => status.name).toList(growable: false));

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
              merchantId: row['merchant_id'] == null
                  ? null
                  : MerchantId(row['merchant_id'] as String),
              merchant: _selectAssignedMerchant(row['merchant_id'] as String?),
              itemsCurrency: null,
              items: const <ReceiptItem>[],
              validationWarnings: const <ReceiptValidationWarning>[],
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
          receipts.merchant_id,
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
          .map((row) {
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
              merchantId: row['merchant_id'] == null
                  ? null
                  : MerchantId(row['merchant_id'] as String),
              merchant: _selectAssignedMerchant(row['merchant_id'] as String?),
              itemsCurrency: _selectItemsCurrency(receiptId),
              items: _selectItems(receiptId),
              validationWarnings: _selectValidationWarnings(receiptId),
              extraction: _selectExtraction(receiptId),
            );
          })
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
      final rows = _database.select('SELECT id FROM receipts WHERE id = ?;', [
        receiptId.value,
      ]);
      if (rows.isEmpty) {
        throw ReceiptNotFoundException(
          'Receipt "${receiptId.value}" was not found.',
        );
      }

      _database.execute('DELETE FROM receipts WHERE id = ?;', [
        receiptId.value,
      ]);
    } on AppException {
      rethrow;
    } catch (error) {
      throw PersistenceException('Failed to delete receipt.', cause: error);
    }
  }

  @override
  Future<void> assignMerchant({
    required ReceiptId receiptId,
    required MerchantId merchantId,
  }) async {
    try {
      _database.execute('UPDATE receipts SET merchant_id = ? WHERE id = ?;', [
        merchantId.value,
        receiptId.value,
      ]);
    } catch (error) {
      throw PersistenceException(
        'Failed to assign merchant to receipt.',
        cause: error,
      );
    }
  }

  @override
  Future<void> replaceItems({
    required ReceiptId receiptId,
    required String? currency,
    required List<ReceiptItem> items,
    required List<ReceiptValidationWarning> validationWarnings,
  }) async {
    try {
      _database.execute('BEGIN;');
      _database.execute('DELETE FROM receipt_items WHERE receipt_id = ?;', [
        receiptId.value,
      ]);
      _database.execute(
        'DELETE FROM receipt_validation_warnings WHERE receipt_id = ?;',
        [receiptId.value],
      );
      for (var index = 0; index < items.length; index++) {
        final item = items[index];
        _database.execute(
          '''
          INSERT INTO receipt_items (
            id,
            receipt_id,
            sort_order,
            item_number,
            name,
            total_price,
            quantity,
            category
          ) VALUES (?, ?, ?, ?, ?, ?, ?, ?);
          ''',
          [
            item.id,
            receiptId.value,
            index,
            item.itemNumber,
            item.name,
            item.totalPrice,
            item.quantity,
            item.category?.apiValue,
          ],
        );
      }
      for (final warning in validationWarnings) {
        _database.execute(
          '''
          INSERT INTO receipt_validation_warnings (receipt_id, code, message)
          VALUES (?, ?, ?);
          ''',
          [receiptId.value, warning.code, warning.message],
        );
      }
      _database.execute(
        'UPDATE receipts SET items_currency = ? WHERE id = ?;',
        [currency, receiptId.value],
      );
      _database.execute('COMMIT;');
    } catch (error) {
      _safeRollback();
      throw PersistenceException(
        'Failed to replace receipt items.',
        cause: error,
      );
    }
  }

  @override
  Future<ReceiptItem> getItemById({
    required ReceiptId receiptId,
    required String itemId,
  }) async {
    try {
      final rows = _database.select(
        '''
        SELECT id, item_number, name, total_price, quantity, category
        FROM receipt_items
        WHERE receipt_id = ? AND id = ?;
        ''',
        [receiptId.value, itemId],
      );
      if (rows.isEmpty) {
        throw ReceiptItemNotFoundException(
          'Receipt item "$itemId" was not found for receipt "${receiptId.value}".',
        );
      }

      return _mapReceiptItem(rows.first);
    } on AppException {
      rethrow;
    } catch (error) {
      throw PersistenceException('Failed to load receipt item.', cause: error);
    }
  }

  @override
  Future<void> updateItem({
    required ReceiptId receiptId,
    required ReceiptItem item,
  }) async {
    try {
      _database.execute('BEGIN;');
      _database.execute(
        '''
        UPDATE receipt_items
        SET item_number = ?, name = ?, total_price = ?, quantity = ?, category = ?
        WHERE receipt_id = ? AND id = ?;
        ''',
        [
          item.itemNumber,
          item.name,
          item.totalPrice,
          item.quantity,
          item.category?.apiValue,
          receiptId.value,
          item.id,
        ],
      );

      final extraction = _selectExtraction(receiptId);
      final extractedLineItems = extraction?.structuredData['lineItems'];
      final extractedTotalAmount = extractedLineItems is Map
          ? extractedLineItems['total_amount'] as num?
          : null;
      final warnings = buildReceiptItemValidationWarnings(
        extractedTotalAmount: extractedTotalAmount?.toDouble(),
        items: _selectItems(receiptId),
      );
      _database.execute(
        'DELETE FROM receipt_validation_warnings WHERE receipt_id = ?;',
        [receiptId.value],
      );
      for (final warning in warnings) {
        _database.execute(
          '''
          INSERT INTO receipt_validation_warnings (receipt_id, code, message)
          VALUES (?, ?, ?);
          ''',
          [receiptId.value, warning.code, warning.message],
        );
      }
      _database.execute('COMMIT;');
    } catch (error) {
      _safeRollback();
      throw PersistenceException(
        'Failed to update receipt item.',
        cause: error,
      );
    }
  }

  @override
  Future<bool> hasMerchantAssignment(MerchantId merchantId) async {
    try {
      final rows = _database.select(
        'SELECT id FROM receipts WHERE merchant_id = ? LIMIT 1;',
        [merchantId.value],
      );
      return rows.isNotEmpty;
    } catch (error) {
      throw PersistenceException(
        'Failed to inspect receipt merchant assignments.',
        cause: error,
      );
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
        receipts.merchant_id,
        receipts.items_currency,
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
      throw ReceiptNotFoundException(
        'Receipt "${receiptId.value}" was not found.',
      );
    }

    return rows.first;
  }

  Merchant? _selectAssignedMerchant(String? merchantId) {
    if (merchantId == null || merchantId.isEmpty) {
      return null;
    }

    final rows = _database.select(
      '''
      SELECT id, name, street, post_code, city, tax_id
      FROM merchants
      WHERE id = ?;
      ''',
      [merchantId],
    );
    if (rows.isEmpty) {
      return null;
    }

    final row = rows.first;
    return Merchant(
      id: MerchantId(row['id'] as String),
      name: row['name'] as String,
      street: row['street'] as String,
      postCode: row['post_code'] as String,
      city: row['city'] as String,
      taxId: _nullableTaxId(row['tax_id'] as String),
    );
  }

  String? _selectItemsCurrency(ReceiptId receiptId) {
    final rows = _database.select(
      'SELECT items_currency FROM receipts WHERE id = ?;',
      [receiptId.value],
    );
    if (rows.isEmpty) {
      return null;
    }

    return rows.first['items_currency'] as String?;
  }

  List<ReceiptItem> _selectItems(ReceiptId receiptId) {
    final rows = _database.select(
      '''
      SELECT id, item_number, name, total_price, quantity, category
      FROM receipt_items
      WHERE receipt_id = ?
      ORDER BY sort_order ASC, id ASC;
      ''',
      [receiptId.value],
    );
    return rows.map(_mapReceiptItem).toList(growable: false);
  }

  ReceiptItem _mapReceiptItem(sqlite.Row row) {
    return ReceiptItem(
      id: row['id'] as String,
      itemNumber: row['item_number'] as String?,
      name: row['name'] as String?,
      totalPrice: (row['total_price'] as num?)?.toDouble(),
      quantity: row['quantity'] as int?,
      category: (row['category'] as String?) == null
          ? null
          : ReceiptItemCategory.fromApiValue(row['category'] as String),
    );
  }

  List<ReceiptValidationWarning> _selectValidationWarnings(
    ReceiptId receiptId,
  ) {
    final rows = _database.select(
      '''
      SELECT code, message
      FROM receipt_validation_warnings
      WHERE receipt_id = ?
      ORDER BY id ASC;
      ''',
      [receiptId.value],
    );
    return rows
        .map(
          (row) => ReceiptValidationWarning(
            code: row['code'] as String,
            message: row['message'] as String,
          ),
        )
        .toList(growable: false);
  }

  ReceiptExtraction? _selectExtraction(ReceiptId receiptId) {
    final rows = _database.select(
      '''
      SELECT request_id, raw_text, ocr_json, metadata_json
      , structured_json
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
      structuredData: _decodeJsonMap(row['structured_json'] as String),
      metadata: _decodeJsonMap(row['metadata_json'] as String),
      warnings: warnings,
    );
  }

  void _updateReceipt({
    required ReceiptId receiptId,
    required ReceiptStatus status,
  }) {
    try {
      _database.execute('UPDATE receipts SET status = ? WHERE id = ?;', [
        status.name,
        receiptId.value,
      ]);
    } catch (error) {
      throw PersistenceException(
        'Failed to update receipt status.',
        cause: error,
      );
    }
  }

  void _deleteExtractionRows(ReceiptId receiptId) {
    _database.execute('DELETE FROM receipt_warnings WHERE receipt_id = ?;', [
      receiptId.value,
    ]);
    _database.execute('DELETE FROM receipt_extractions WHERE receipt_id = ?;', [
      receiptId.value,
    ]);
  }

  void _deleteItemsRows(ReceiptId receiptId) {
    _database.execute(
      'DELETE FROM receipt_validation_warnings WHERE receipt_id = ?;',
      [receiptId.value],
    );
    _database.execute('DELETE FROM receipt_items WHERE receipt_id = ?;', [
      receiptId.value,
    ]);
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
        structured_json,
        metadata_json
      ) VALUES (?, ?, ?, ?, ?, ?);
      ''',
      [
        receiptId.value,
        requestId.value,
        extraction.rawText,
        jsonEncode(extraction.ocrData),
        jsonEncode(extraction.structuredData),
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

  void _insertItems({
    required ReceiptId receiptId,
    required String? currency,
    required List<ReceiptItem> items,
    required List<ReceiptValidationWarning> validationWarnings,
  }) {
    for (var index = 0; index < items.length; index++) {
      final item = items[index];
      _database.execute(
        '''
        INSERT INTO receipt_items (
          id,
          receipt_id,
          sort_order,
          item_number,
          name,
          total_price,
          quantity,
          category
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?);
        ''',
        [
          item.id,
          receiptId.value,
          index,
          item.itemNumber,
          item.name,
          item.totalPrice,
          item.quantity,
          item.category?.apiValue,
        ],
      );
    }
    for (final warning in validationWarnings) {
      _database.execute(
        '''
        INSERT INTO receipt_validation_warnings (receipt_id, code, message)
        VALUES (?, ?, ?);
        ''',
        [receiptId.value, warning.code, warning.message],
      );
    }
    _database.execute('UPDATE receipts SET items_currency = ? WHERE id = ?;', [
      currency,
      receiptId.value,
    ]);
  }

  void _safeRollback() {
    try {
      _database.execute('ROLLBACK;');
    } catch (_) {
      // Ignore rollback errors.
    }
  }
}

String? _nullableTaxId(String value) {
  final trimmed = value.trim();
  return trimmed.isEmpty ? null : trimmed;
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
