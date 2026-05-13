import 'dart:io';

import 'package:path/path.dart' as path;
import 'package:ris_core/ris_core.dart';

import '../../domain/exceptions/app_exceptions.dart';
import '../../domain/models/receipt.dart';
import '../../domain/repositories/receipt_repository.dart';
import '../../domain/services/extract_service.dart';
import 'auto_assign_receipt_merchant.dart';

class ProcessReceiptExtractionUseCase {
  const ProcessReceiptExtractionUseCase({
    required ReceiptRepository receiptRepository,
    required ExtractService extractService,
    required String dataDirectoryPath,
    required AutoAssignReceiptMerchantUseCase autoAssignReceiptMerchantUseCase,
  }) : _receiptRepository = receiptRepository,
       _extractService = extractService,
       _dataDirectoryPath = dataDirectoryPath,
       _autoAssignReceiptMerchantUseCase = autoAssignReceiptMerchantUseCase;

  final ReceiptRepository _receiptRepository;
  final ExtractService _extractService;
  final String _dataDirectoryPath;
  final AutoAssignReceiptMerchantUseCase _autoAssignReceiptMerchantUseCase;

  Future<void> execute(ReceiptId receiptId) async {
    Receipt receipt;
    try {
      receipt = await _receiptRepository.getById(receiptId);
    } on ReceiptNotFoundException {
      return;
    }
    final requestId = receipt.extractRequestId;

    if (receipt.status == ReceiptStatus.processed &&
        receipt.extraction != null) {
      return;
    }

    await _receiptRepository.updateStatus(
      receiptId: receiptId,
      status: ReceiptStatus.processing,
    );

    try {
      final imageFile = File(
        path.join(_dataDirectoryPath, receipt.image.storagePath),
      );
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
      await _autoAssignReceiptMerchantUseCase.execute(receiptId);
    } on ReceiptNotFoundException {
      return;
    } catch (_) {
      await _receiptRepository.clearExtraction(
        receiptId: receiptId,
        requestId: requestId,
        status: ReceiptStatus.failed,
      );
    }
  }
}
