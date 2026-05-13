import 'package:ris_core/ris_core.dart';

import '../models/merchant_match.dart';
import '../models/receipt.dart';

abstract interface class ReceiptRepository {
  Future<void> create(Receipt receipt);

  Future<void> createMerchantMatchProperties({
    required MerchantId merchantId,
    required List<MerchantMatchProperty> properties,
  });

  Future<List<MerchantCandidateScore>> scoreMerchantCandidates(
    List<MerchantMatchProperty> properties,
  );

  Future<Receipt> getById(ReceiptId receiptId);

  Future<void> updateStatus({
    required ReceiptId receiptId,
    required ReceiptStatus status,
  });

  Future<void> replacePendingExtraction({
    required ReceiptId receiptId,
    required ExtractRequestId requestId,
  });

  Future<void> saveProcessedExtraction({
    required ReceiptId receiptId,
    required ExtractRequestId requestId,
    required ExtractResponse extraction,
  });

  Future<void> replaceItems({
    required ReceiptId receiptId,
    required String? currency,
    required List<ReceiptItem> items,
    required List<ReceiptValidationWarning> validationWarnings,
  });

  Future<ReceiptItem> getItemById({
    required ReceiptId receiptId,
    required String itemId,
  });

  Future<void> updateItem({
    required ReceiptId receiptId,
    required ReceiptItem item,
  });

  Future<void> clearExtraction({
    required ReceiptId receiptId,
    required ExtractRequestId requestId,
    required ReceiptStatus status,
  });

  Future<List<Receipt>> listByStatuses(List<ReceiptStatus> statuses);

  Future<List<Receipt>> list({required int limit, required int offset});

  Future<void> assignMerchant({
    required ReceiptId receiptId,
    required MerchantId merchantId,
    required MerchantAssignedType assignedType,
  });

  Future<void> clearMerchantAssignment(ReceiptId receiptId);

  Future<bool> hasMerchantAssignment(MerchantId merchantId);

  Future<void> delete(ReceiptId receiptId);
}
