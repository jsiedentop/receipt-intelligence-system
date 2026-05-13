import 'package:ris_core/ris_core.dart';

import 'merchant_create_repository.dart';

class RisMerchantCreateRepository implements MerchantCreateRepository {
  const RisMerchantCreateRepository(this._backendClient);

  final BackendClient _backendClient;

  @override
  Future<MerchantResponseDto> createMerchant({
    required String name,
    required String street,
    required String postCode,
    required String city,
    required String taxId,
  }) {
    return _backendClient.createMerchant(
      name: name,
      street: street,
      postCode: postCode,
      city: city,
      taxId: taxId,
    );
  }
}
