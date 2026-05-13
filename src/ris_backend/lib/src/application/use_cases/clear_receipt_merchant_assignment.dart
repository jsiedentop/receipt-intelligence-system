import 'package:ris_core/ris_core.dart';

import '../../domain/exceptions/app_exceptions.dart';
import '../../domain/models/receipt.dart';
import '../../domain/repositories/receipt_repository.dart';

class ClearReceiptMerchantAssignmentUseCase {
  const ClearReceiptMerchantAssignmentUseCase({
    required ReceiptRepository receiptRepository,
  }) : _receiptRepository = receiptRepository;

  final ReceiptRepository _receiptRepository;

  Future<Receipt> execute(ReceiptId receiptId) async {
    final receipt = await _receiptRepository.getById(receiptId);
    if (receipt.merchantId == null) {
      throw ReceiptMerchantAssignmentNotFoundException(
        'Receipt "${receiptId.value}" has no assigned merchant.',
      );
    }

    await _receiptRepository.clearMerchantAssignment(receiptId);
    return _receiptRepository.getById(receiptId);
  }
}
