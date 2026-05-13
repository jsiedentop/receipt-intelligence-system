import 'package:ris_core/ris_core.dart';

import '../../domain/models/merchant.dart';
import '../../domain/repositories/merchant_repository.dart';

class DeleteMerchantMatchPropertyUseCase {
  const DeleteMerchantMatchPropertyUseCase({
    required MerchantRepository merchantRepository,
  }) : _merchantRepository = merchantRepository;

  final MerchantRepository _merchantRepository;

  Future<Merchant> execute({
    required MerchantId merchantId,
    required int propertyId,
  }) async {
    await _merchantRepository.deleteMatchProperty(
      merchantId: merchantId,
      propertyId: propertyId,
    );
    return _merchantRepository.getById(merchantId);
  }
}
