import 'package:ris_core/ris_core.dart';

class SelectedReceiptFile {
  const SelectedReceiptFile({
    required this.name,
    required this.bytes,
    required this.mimeType,
  });

  final String name;
  final List<int> bytes;
  final String mimeType;
}

abstract interface class ReceiptUploadRepository {
  Future<ReceiptResponseDto> uploadReceipt(SelectedReceiptFile file);

  Future<ReceiptResponseDto> getReceiptById(ReceiptId receiptId);
}
