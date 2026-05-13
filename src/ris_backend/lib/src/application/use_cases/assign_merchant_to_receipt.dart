import 'package:ris_core/ris_core.dart';

import '../../domain/exceptions/app_exceptions.dart';
import '../../domain/models/merchant_match.dart';
import '../../domain/models/receipt.dart';
import '../../domain/repositories/merchant_repository.dart';
import '../../domain/repositories/receipt_repository.dart';

class AssignMerchantToReceiptUseCase {
  const AssignMerchantToReceiptUseCase({
    required ReceiptRepository receiptRepository,
    required MerchantRepository merchantRepository,
  }) : _receiptRepository = receiptRepository,
       _merchantRepository = merchantRepository;

  final ReceiptRepository _receiptRepository;
  final MerchantRepository _merchantRepository;

  Future<Receipt> execute({
    required ReceiptId receiptId,
    required MerchantId merchantId,
  }) async {
    final receipt = await _receiptRepository.getById(receiptId);
    if (receipt.merchantId != null) {
      throw ReceiptMerchantConflictException(
        'Receipt "${receiptId.value}" already has an assigned merchant.',
      );
    }

    await _merchantRepository.getById(merchantId);
    await _receiptRepository.assignMerchant(
      receiptId: receiptId,
      merchantId: merchantId,
      assignedType: MerchantAssignedType.manual,
    );
    await _receiptRepository.createMerchantMatchProperties(
      merchantId: merchantId,
      properties: extractMerchantMatchProperties(receipt.extraction),
    );

    return _receiptRepository.getById(receiptId);
  }
}
