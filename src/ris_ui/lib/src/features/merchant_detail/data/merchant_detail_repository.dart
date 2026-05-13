import 'package:ris_core/ris_core.dart';

abstract interface class MerchantDetailRepository {
  Future<MerchantResponseDto> getMerchantById(MerchantId merchantId);

  Future<void> deleteMerchant(MerchantId merchantId);
}
