import 'package:ris_core/ris_core.dart';

import 'merchants_list_repository.dart';

class RisMerchantsListRepository implements MerchantsListRepository {
  const RisMerchantsListRepository(this._backendClient);

  final BackendClient _backendClient;

  @override
  Future<List<MerchantResponseDto>> listMerchants() {
    return _backendClient.listMerchants();
  }
}
