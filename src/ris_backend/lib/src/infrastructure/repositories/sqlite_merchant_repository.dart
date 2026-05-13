import 'package:ris_core/ris_core.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite;

import '../../domain/exceptions/app_exceptions.dart';
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
          merchant.taxId,
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
      taxId: row['tax_id'] as String,
    );
  }
}
