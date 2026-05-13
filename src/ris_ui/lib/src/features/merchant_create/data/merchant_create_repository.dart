import 'package:ris_core/ris_core.dart';

abstract interface class MerchantCreateRepository {
  Future<MerchantResponseDto> createMerchant({
    required String name,
    required String street,
    required String postCode,
    required String city,
    required String taxId,
  });
}
