import 'package:ris_core/ris_core.dart';

import 'receipt_upload_repository.dart';

class RisReceiptUploadRepository implements ReceiptUploadRepository {
  const RisReceiptUploadRepository(this._backendClient);

  final BackendClient _backendClient;

  @override
  Future<ReceiptResponseDto> getReceiptById(ReceiptId receiptId) {
    return _backendClient.getReceiptById(receiptId);
  }

  @override
  Future<ReceiptResponseDto> uploadReceipt(SelectedReceiptFile file) {
    return _backendClient.createReceipt(
      bytes: file.bytes,
      fileName: file.name,
      mimeType: file.mimeType,
    );
  }
}
