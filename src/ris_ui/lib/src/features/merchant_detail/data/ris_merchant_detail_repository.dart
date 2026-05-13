import 'package:ris_core/ris_core.dart';

import 'merchant_detail_repository.dart';

class RisMerchantDetailRepository implements MerchantDetailRepository {
  const RisMerchantDetailRepository(this._backendClient);

  final BackendClient _backendClient;

  @override
  Future<void> deleteMerchant(MerchantId merchantId) {
    return _backendClient.deleteMerchant(merchantId);
  }

  @override
  Future<MerchantResponseDto> getMerchantById(MerchantId merchantId) {
    return _backendClient.getMerchantById(merchantId);
  }
}
