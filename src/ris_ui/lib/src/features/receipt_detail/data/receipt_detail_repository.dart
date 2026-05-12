import 'package:ris_core/ris_core.dart';

abstract interface class ReceiptDetailRepository {
  Future<ReceiptResponseDto> getReceiptById(ReceiptId receiptId);

  Future<BackendReceiptImage> getReceiptImage(ReceiptId receiptId);

  Future<ReceiptResponseDto> restartReceiptExtraction(ReceiptId receiptId);

  Future<void> deleteReceipt(ReceiptId receiptId);
}
