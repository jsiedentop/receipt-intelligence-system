import 'package:ris_core/ris_core.dart';

import '../../domain/models/merchant.dart';
import '../../domain/repositories/merchant_repository.dart';

class GetMerchantUseCase {
  const GetMerchantUseCase({required MerchantRepository merchantRepository})
    : _merchantRepository = merchantRepository;

  final MerchantRepository _merchantRepository;

  Future<Merchant> execute(MerchantId merchantId) {
    return _merchantRepository.getById(merchantId);
  }
}
