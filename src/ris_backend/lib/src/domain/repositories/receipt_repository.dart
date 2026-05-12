import 'package:ris_core/ris_core.dart';

import '../models/receipt.dart';

abstract interface class ReceiptRepository {
  Future<void> create(Receipt receipt);

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

  Future<void> clearExtraction({
    required ReceiptId receiptId,
    required ExtractRequestId requestId,
    required ReceiptStatus status,
  });

  Future<List<Receipt>> listByStatuses(List<ReceiptStatus> statuses);

  Future<List<Receipt>> list({required int limit, required int offset});
}
