import 'package:ris_core/ris_core.dart';

abstract interface class ReceiptDetailRepository {
  Future<ReceiptResponseDto> getReceiptById(ReceiptId receiptId);

  Future<BackendReceiptImage> getReceiptImage(ReceiptId receiptId);

  Future<ReceiptResponseDto> createMerchantForReceipt({
    required ReceiptId receiptId,
    required String name,
    required String street,
    required String postCode,
    required String city,
    required String? taxId,
  });

  Future<ReceiptResponseDto> updateReceiptItem({
    required ReceiptId receiptId,
    required String itemId,
    required String? itemNumber,
    required String? name,
    required double? totalPrice,
    required int? quantity,
    required ReceiptItemCategory? category,
  });

  Future<ReceiptResponseDto> restartReceiptExtraction(ReceiptId receiptId);

  Future<void> deleteReceipt(ReceiptId receiptId);
}
