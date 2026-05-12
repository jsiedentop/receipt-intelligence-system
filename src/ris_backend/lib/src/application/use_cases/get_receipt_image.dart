import 'package:ris_core/ris_core.dart';

import '../../domain/repositories/image_storage_repository.dart';
import '../../domain/repositories/receipt_repository.dart';

class ReceiptImage {
  const ReceiptImage({required this.mimeType, required this.bytes});

  final String mimeType;
  final List<int> bytes;
}

class GetReceiptImageUseCase {
  const GetReceiptImageUseCase({
    required ReceiptRepository receiptRepository,
    required ImageStorageRepository imageStorageRepository,
  }) : _receiptRepository = receiptRepository,
       _imageStorageRepository = imageStorageRepository;

  final ReceiptRepository _receiptRepository;
  final ImageStorageRepository _imageStorageRepository;

  Future<ReceiptImage> execute(ReceiptId receiptId) async {
    final receipt = await _receiptRepository.getById(receiptId);
    final bytes = await _imageStorageRepository.read(receipt.image.storagePath);
    return ReceiptImage(mimeType: receipt.image.mimeType, bytes: bytes);
  }
}
