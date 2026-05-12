import '../../domain/models/receipt.dart';
import '../../domain/repositories/receipt_repository.dart';

class ListReceiptsUseCase {
  const ListReceiptsUseCase({required ReceiptRepository receiptRepository})
    : _receiptRepository = receiptRepository;

  final ReceiptRepository _receiptRepository;

  Future<List<Receipt>> execute({required int page, required int pageSize}) {
    final offset = (page - 1) * pageSize;
    return _receiptRepository.list(limit: pageSize, offset: offset);
  }
}
