import '../../domain/models/merchant.dart';
import '../../domain/repositories/merchant_repository.dart';

class ListMerchantsUseCase {
  const ListMerchantsUseCase({required MerchantRepository merchantRepository})
    : _merchantRepository = merchantRepository;

  final MerchantRepository _merchantRepository;

  Future<List<Merchant>> execute() {
    return _merchantRepository.list();
  }
}
