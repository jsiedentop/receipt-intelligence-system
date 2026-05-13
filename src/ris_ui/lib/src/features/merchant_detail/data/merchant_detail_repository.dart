import 'package:ris_core/ris_core.dart';

abstract interface class MerchantDetailRepository {
  Future<MerchantResponseDto> getMerchantById(MerchantId merchantId);

  Future<MerchantResponseDto> deleteMerchantMatchProperty({
    required MerchantId merchantId,
    required int propertyId,
  });

  Future<void> deleteMerchant(MerchantId merchantId);
}
