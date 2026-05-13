import 'package:mime/mime.dart';
import 'package:ris_core/ris_core.dart';

import '../services/extraction_job_dispatcher.dart';
import '../../domain/exceptions/app_exceptions.dart';
import '../../domain/models/receipt.dart';
import '../../domain/repositories/image_storage_repository.dart';
import '../../domain/repositories/receipt_repository.dart';

class CreateReceiptCommand {
  const CreateReceiptCommand({
    required this.fileName,
    required this.mimeType,
    required this.bytes,
  });

  final String fileName;
  final String? mimeType;
  final List<int> bytes;
}

class CreateReceiptUseCase {
  CreateReceiptUseCase({
    required ReceiptRepository receiptRepository,
    required ImageStorageRepository imageStorageRepository,
    required ExtractionJobDispatcher extractionJobDispatcher,
  }) : _receiptRepository = receiptRepository,
       _imageStorageRepository = imageStorageRepository,
       _extractionJobDispatcher = extractionJobDispatcher;

  final ReceiptRepository _receiptRepository;
  final ImageStorageRepository _imageStorageRepository;
  final ExtractionJobDispatcher _extractionJobDispatcher;

  Future<Receipt> execute(CreateReceiptCommand command) async {
    if (command.bytes.isEmpty) {
      throw MissingUploadFileException('Uploaded file is empty.');
    }

    final mimeType = _resolveMimeType(command);
    final receiptId = ReceiptId.create();
    final extractRequestId = ExtractRequestId.create();

    StoredReceiptImage? image;
    try {
      image = await _imageStorageRepository.store(
        receiptId: receiptId,
        originalFileName: command.fileName,
        mimeType: mimeType,
        bytes: command.bytes,
      );

      final receipt = Receipt(
        id: receiptId,
        createdAt: DateTime.now().toUtc(),
        status: ReceiptStatus.pending,
        image: image,
        extractRequestId: extractRequestId,
        merchantId: null,
        merchant: null,
        itemsCurrency: null,
        items: const <ReceiptItem>[],
        validationWarnings: const <ReceiptValidationWarning>[],
        extraction: null,
      );

      await _receiptRepository.create(receipt);
      _extractionJobDispatcher.schedule(receiptId);
      return receipt;
    } on AppException {
      if (image != null) {
        await _deleteStoredImageSilently(image.storagePath);
      }
      rethrow;
    } catch (error) {
      if (image != null) {
        await _deleteStoredImageSilently(image.storagePath);
      }
      throw PersistenceException('Failed to create receipt.', cause: error);
    }
  }

  String _resolveMimeType(CreateReceiptCommand command) {
    final detectedMimeType = lookupMimeType(
      command.fileName,
      headerBytes: command.bytes,
    );
    final mimeType = command.mimeType ?? detectedMimeType;
    if (mimeType == null) {
      throw UnsupportedMediaTypeException(
        'Unable to determine uploaded file type.',
      );
    }

    if (!_supportedMimeTypes.contains(mimeType)) {
      throw UnsupportedMediaTypeException('Unsupported file type: $mimeType.');
    }

    return mimeType;
  }

  Future<void> _deleteStoredImageSilently(String storagePath) async {
    try {
      await _imageStorageRepository.delete(storagePath);
    } catch (_) {
      // Ignore cleanup failures to preserve the original error.
    }
  }
}

const _supportedMimeTypes = {'image/png', 'image/jpeg'};
