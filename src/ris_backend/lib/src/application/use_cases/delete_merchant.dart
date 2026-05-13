import 'package:ris_core/ris_core.dart';

import '../../domain/exceptions/app_exceptions.dart';
import '../../domain/repositories/merchant_repository.dart';
import '../../domain/repositories/receipt_repository.dart';

class DeleteMerchantUseCase {
  const DeleteMerchantUseCase({
    required MerchantRepository merchantRepository,
    required ReceiptRepository receiptRepository,
  }) : _merchantRepository = merchantRepository,
       _receiptRepository = receiptRepository;

  final MerchantRepository _merchantRepository;
  final ReceiptRepository _receiptRepository;

  Future<void> execute(MerchantId merchantId) async {
    if (await _receiptRepository.hasMerchantAssignment(merchantId)) {
      throw ReceiptMerchantConflictException(
        'Merchant "${merchantId.value}" is still assigned to receipts.',
      );
    }

    return _merchantRepository.delete(merchantId);
  }
}
