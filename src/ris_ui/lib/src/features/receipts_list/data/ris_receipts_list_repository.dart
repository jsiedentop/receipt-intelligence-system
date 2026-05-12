import 'package:ris_core/ris_core.dart';

import 'receipts_list_repository.dart';

class RisReceiptsListRepository implements ReceiptsListRepository {
  const RisReceiptsListRepository(this._backendClient);

  final BackendClient _backendClient;

  @override
  Future<List<ReceiptResponseDto>> listReceipts({
    required int page,
    required int pageSize,
  }) {
    return _backendClient.listReceipts(page: page, pageSize: pageSize);
  }
}
