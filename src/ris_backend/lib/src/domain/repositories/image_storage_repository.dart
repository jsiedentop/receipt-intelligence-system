import 'package:ris_core/ris_core.dart';

import '../models/receipt.dart';

abstract interface class ImageStorageRepository {
  Future<StoredReceiptImage> store({
    required ReceiptId receiptId,
    required String originalFileName,
    required String mimeType,
    required List<int> bytes,
  });

  Future<List<int>> read(String storagePath);

  Future<void> delete(String storagePath);
}
