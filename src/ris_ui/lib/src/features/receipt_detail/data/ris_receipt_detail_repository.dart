import 'package:ris_core/ris_core.dart';

import 'receipt_detail_repository.dart';

class RisReceiptDetailRepository implements ReceiptDetailRepository {
  const RisReceiptDetailRepository(this._backendClient);

  final BackendClient _backendClient;

  @override
  Future<void> deleteReceipt(ReceiptId receiptId) {
    return _backendClient.deleteReceipt(receiptId);
  }

  @override
  Future<ReceiptResponseDto> createMerchantForReceipt({
    required ReceiptId receiptId,
    required String name,
    required String street,
    required String postCode,
    required String city,
    required String taxId,
  }) {
    return _backendClient.createMerchantForReceipt(
      receiptId: receiptId,
      name: name,
      street: street,
      postCode: postCode,
      city: city,
      taxId: taxId,
    );
  }

  @override
  Future<ReceiptResponseDto> getReceiptById(ReceiptId receiptId) {
    return _backendClient.getReceiptById(receiptId);
  }

  @override
  Future<ReceiptResponseDto> updateReceiptItem({
    required ReceiptId receiptId,
    required String itemId,
    required String? itemNumber,
    required String? name,
    required double? totalPrice,
    required int? quantity,
    required ReceiptItemCategory? category,
  }) {
    return _backendClient.updateReceiptItem(
      receiptId: receiptId,
      itemId: itemId,
      itemNumber: itemNumber,
      name: name,
      totalPrice: totalPrice,
      quantity: quantity,
      category: category,
    );
  }

  @override
  Future<BackendReceiptImage> getReceiptImage(ReceiptId receiptId) {
    return _backendClient.getReceiptImage(receiptId);
  }

  @override
  Future<ReceiptResponseDto> restartReceiptExtraction(ReceiptId receiptId) {
    return _backendClient.restartReceiptExtraction(receiptId);
  }
}
