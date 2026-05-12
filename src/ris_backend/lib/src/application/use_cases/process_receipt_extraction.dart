import 'dart:io';

import 'package:path/path.dart' as path;
import 'package:ris_core/ris_core.dart';

import '../../domain/models/receipt.dart';
import '../../domain/repositories/receipt_repository.dart';
import '../../domain/services/extract_service.dart';

class ProcessReceiptExtractionUseCase {
  const ProcessReceiptExtractionUseCase({
    required ReceiptRepository receiptRepository,
    required ExtractService extractService,
    required String dataDirectoryPath,
  }) : _receiptRepository = receiptRepository,
       _extractService = extractService,
       _dataDirectoryPath = dataDirectoryPath;

  final ReceiptRepository _receiptRepository;
  final ExtractService _extractService;
  final String _dataDirectoryPath;

  Future<void> execute(ReceiptId receiptId) async {
    final receipt = await _receiptRepository.getById(receiptId);
    final requestId = receipt.extractRequestId;

    if (receipt.status == ReceiptStatus.processed && receipt.extraction != null) {
      return;
    }

    await _receiptRepository.updateStatus(
      receiptId: receiptId,
      status: ReceiptStatus.processing,
    );

    try {
      final imageFile = File(path.join(_dataDirectoryPath, receipt.image.storagePath));
      final bytes = await imageFile.readAsBytes();
      final extraction = await _extractService.extractReceipt(
        requestId: requestId,
        bytes: bytes,
        fileName: receipt.image.originalFileName,
        mimeType: receipt.image.mimeType,
      );
      await _receiptRepository.saveProcessedExtraction(
        receiptId: receiptId,
        requestId: requestId,
        extraction: extraction,
      );
    } catch (_) {
      await _receiptRepository.clearExtraction(
        receiptId: receiptId,
        requestId: requestId,
        status: ReceiptStatus.failed,
      );
    }
  }
}
