import 'package:ris_core/ris_core.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite;

import '../../domain/exceptions/app_exceptions.dart';
import '../../domain/models/merchant_match.dart';
import '../../domain/models/merchant.dart';
import '../../domain/repositories/merchant_repository.dart';

class SqliteMerchantRepository implements MerchantRepository {
  const SqliteMerchantRepository(this._database);

  final sqlite.Database _database;

  @override
  Future<void> create(Merchant merchant) async {
    try {
      _database.execute(
        '''
        INSERT INTO merchants (id, name, street, post_code, city, tax_id)
        VALUES (?, ?, ?, ?, ?, ?);
        ''',
        [
          merchant.id.value,
          merchant.name,
          merchant.street,
          merchant.postCode,
          merchant.city,
          merchant.taxId ?? '',
        ],
      );
    } catch (error) {
      throw PersistenceException('Failed to persist merchant.', cause: error);
    }
  }

  @override
  Future<Merchant> getById(MerchantId merchantId) async {
    try {
      final rows = _database.select(
        'SELECT id, name, street, post_code, city, tax_id FROM merchants WHERE id = ?;',
        [merchantId.value],
      );
      if (rows.isEmpty) {
        throw MerchantNotFoundException(
          'Merchant "${merchantId.value}" was not found.',
        );
      }

      return _mapRow(rows.first);
    } on AppException {
      rethrow;
    } catch (error) {
      throw PersistenceException('Failed to load merchant.', cause: error);
    }
  }

  @override
  Future<List<MerchantStoredMatchProperty>> listMatchProperties(
    MerchantId merchantId,
  ) async {
    try {
      final merchantRows = _database.select(
        'SELECT id FROM merchants WHERE id = ?;',
        [merchantId.value],
      );
      if (merchantRows.isEmpty) {
        throw MerchantNotFoundException(
          'Merchant "${merchantId.value}" was not found.',
        );
      }

      final rows = _database.select(
        '''
        SELECT id, property_type, property_value_raw, property_value_normalized
        FROM merchant_match_properties
        WHERE merchant_id = ?
        ORDER BY property_type ASC, property_value_raw ASC, id ASC;
        ''',
        [merchantId.value],
      );

      return rows.map(_mapMatchPropertyRow).toList(growable: false);
    } on AppException {
      rethrow;
    } catch (error) {
      throw PersistenceException(
        'Failed to load merchant match properties.',
        cause: error,
      );
    }
  }

  @override
  Future<void> deleteMatchProperty({
    required MerchantId merchantId,
    required int propertyId,
  }) async {
    try {
      final rows = _database.select(
        '''
        SELECT id
        FROM merchant_match_properties
        WHERE merchant_id = ? AND id = ?;
        ''',
        [merchantId.value, propertyId],
      );
      if (rows.isEmpty) {
        throw MerchantNotFoundException(
          'Merchant match property "$propertyId" was not found for merchant "${merchantId.value}".',
        );
      }

      _database.execute(
        'DELETE FROM merchant_match_properties WHERE merchant_id = ? AND id = ?;',
        [merchantId.value, propertyId],
      );
    } on AppException {
      rethrow;
    } catch (error) {
      throw PersistenceException(
        'Failed to delete merchant match property.',
        cause: error,
      );
    }
  }

  @override
  Future<List<Merchant>> list() async {
    try {
      final rows = _database.select(
        'SELECT id, name, street, post_code, city, tax_id FROM merchants ORDER BY name ASC, id ASC;',
      );
      return rows.map(_mapRow).toList(growable: false);
    } catch (error) {
      throw PersistenceException('Failed to load merchants.', cause: error);
    }
  }

  @override
  Future<void> delete(MerchantId merchantId) async {
    try {
      final rows = _database.select('SELECT id FROM merchants WHERE id = ?;', [
        merchantId.value,
      ]);
      if (rows.isEmpty) {
        throw MerchantNotFoundException(
          'Merchant "${merchantId.value}" was not found.',
        );
      }

      _database.execute('DELETE FROM merchants WHERE id = ?;', [
        merchantId.value,
      ]);
    } on AppException {
      rethrow;
    } catch (error) {
      throw PersistenceException('Failed to delete merchant.', cause: error);
    }
  }

  Merchant _mapRow(sqlite.Row row) {
    return Merchant(
      id: MerchantId(row['id'] as String),
      name: row['name'] as String,
      street: row['street'] as String,
      postCode: row['post_code'] as String,
      city: row['city'] as String,
      taxId: _nullableTaxId(row['tax_id'] as String),
      matchProperties: _selectMatchProperties(MerchantId(row['id'] as String)),
    );
  }

  List<MerchantStoredMatchProperty> _selectMatchProperties(MerchantId merchantId) {
    final rows = _database.select(
      '''
      SELECT id, property_type, property_value_raw, property_value_normalized
      FROM merchant_match_properties
      WHERE merchant_id = ?
      ORDER BY property_type ASC, property_value_raw ASC, id ASC;
      ''',
      [merchantId.value],
    );
    return rows.map(_mapMatchPropertyRow).toList(growable: false);
  }

  MerchantStoredMatchProperty _mapMatchPropertyRow(sqlite.Row row) {
    return MerchantStoredMatchProperty(
      id: row['id'] as int,
      type: MerchantMatchPropertyType.fromApiValue(
        row['property_type'] as String,
      ),
      rawValue: row['property_value_raw'] as String,
      normalizedValue: row['property_value_normalized'] as String,
    );
  }
}

String? _nullableTaxId(String value) {
  final trimmed = value.trim();
  return trimmed.isEmpty ? null : trimmed;
}
