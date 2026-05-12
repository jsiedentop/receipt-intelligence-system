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
  Future<ReceiptResponseDto> getReceiptById(ReceiptId receiptId) {
    return _backendClient.getReceiptById(receiptId);
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
