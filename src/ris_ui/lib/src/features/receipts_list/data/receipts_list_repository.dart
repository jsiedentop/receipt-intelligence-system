import 'package:ris_core/ris_core.dart';

abstract interface class ReceiptsListRepository {
  Future<List<ReceiptResponseDto>> listReceipts({
    required int page,
    required int pageSize,
  });
}
