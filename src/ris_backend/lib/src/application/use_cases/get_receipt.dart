import 'package:ris_core/ris_core.dart';

import '../../domain/models/receipt.dart';
import '../../domain/repositories/receipt_repository.dart';

class GetReceiptUseCase {
  const GetReceiptUseCase({required ReceiptRepository receiptRepository})
    : _receiptRepository = receiptRepository;

  final ReceiptRepository _receiptRepository;

  Future<Receipt> execute(ReceiptId receiptId) {
    return _receiptRepository.getById(receiptId);
  }
}
