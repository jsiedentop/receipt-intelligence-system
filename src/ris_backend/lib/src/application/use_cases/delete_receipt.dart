import 'package:ris_core/ris_core.dart';

import '../../domain/repositories/image_storage_repository.dart';
import '../../domain/repositories/receipt_repository.dart';

class DeleteReceiptUseCase {
  const DeleteReceiptUseCase({
    required ReceiptRepository receiptRepository,
    required ImageStorageRepository imageStorageRepository,
  }) : _receiptRepository = receiptRepository,
       _imageStorageRepository = imageStorageRepository;

  final ReceiptRepository _receiptRepository;
  final ImageStorageRepository _imageStorageRepository;

  Future<void> execute(ReceiptId receiptId) async {
    final receipt = await _receiptRepository.getById(receiptId);
    await _receiptRepository.delete(receiptId);
    await _imageStorageRepository.delete(receipt.image.storagePath);
  }
}
