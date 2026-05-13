import 'package:ris_core/ris_core.dart';

import '../models/merchant_match.dart';
import '../models/merchant.dart';

abstract interface class MerchantRepository {
  Future<void> create(Merchant merchant);

  Future<Merchant> getById(MerchantId merchantId);

  Future<List<MerchantStoredMatchProperty>> listMatchProperties(
    MerchantId merchantId,
  );

  Future<void> deleteMatchProperty({
    required MerchantId merchantId,
    required int propertyId,
  });

  Future<List<Merchant>> list();

  Future<void> delete(MerchantId merchantId);
}
