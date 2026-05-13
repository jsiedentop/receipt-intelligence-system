import 'package:ris_core/ris_core.dart';

abstract interface class MerchantsListRepository {
  Future<List<MerchantResponseDto>> listMerchants();
}
