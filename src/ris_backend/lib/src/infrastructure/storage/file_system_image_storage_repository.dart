import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as path;
import 'package:ris_core/ris_core.dart';

import '../../domain/exceptions/app_exceptions.dart';
import '../../domain/models/receipt.dart';
import '../../domain/repositories/image_storage_repository.dart';

class FileSystemImageStorageRepository implements ImageStorageRepository {
  const FileSystemImageStorageRepository({
    required this.dataDirectoryPath,
    required this.receiptsImageDirectoryPath,
  });

  final String dataDirectoryPath;
  final String receiptsImageDirectoryPath;

  @override
  Future<StoredReceiptImage> store({
    required ReceiptId receiptId,
    required String originalFileName,
    required String mimeType,
    required List<int> bytes,
  }) async {
    try {
      final extension = _resolveFileExtension(originalFileName, mimeType);
      final receiptDirectory = Directory(
        path.join(receiptsImageDirectoryPath, receiptId.value),
      );
      await receiptDirectory.create(recursive: true);

      final absolutePath = path.join(receiptDirectory.path, 'original$extension');
      final file = File(absolutePath);
      await file.writeAsBytes(bytes, flush: true);

      return StoredReceiptImage(
        originalFileName: originalFileName,
        mimeType: mimeType,
        storagePath: path.relative(absolutePath, from: dataDirectoryPath),
        sha256: sha256.convert(bytes).bytes.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join(),
        sizeBytes: bytes.length,
      );
    } catch (error) {
      throw StorageWriteException('Failed to store uploaded image.', cause: error);
    }
  }

  @override
  Future<void> delete(String storagePath) async {
    try {
      final absolutePath = path.join(dataDirectoryPath, storagePath);
      final file = File(absolutePath);
      if (await file.exists()) {
        await file.delete();
      }
    } catch (error) {
      throw StorageWriteException('Failed to delete stored image.', cause: error);
    }
  }
}

String _resolveFileExtension(String originalFileName, String mimeType) {
  final extension = path.extension(originalFileName);
  if (extension.isNotEmpty) {
    return extension;
  }

  return switch (mimeType) {
    'image/png' => '.png',
    'image/jpeg' => '.jpg',
    _ => '',
  };
}
