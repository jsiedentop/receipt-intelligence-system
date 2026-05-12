import 'package:ris_core/ris_core.dart';

import '../services/extraction_job_dispatcher.dart';
import '../../domain/exceptions/app_exceptions.dart';
import '../../domain/models/receipt.dart';
import '../../domain/repositories/receipt_repository.dart';

class RestartReceiptExtractionUseCase {
  const RestartReceiptExtractionUseCase({
    required ReceiptRepository receiptRepository,
    required ExtractionJobDispatcher extractionJobDispatcher,
  }) : _receiptRepository = receiptRepository,
       _extractionJobDispatcher = extractionJobDispatcher;

  final ReceiptRepository _receiptRepository;
  final ExtractionJobDispatcher _extractionJobDispatcher;

  Future<Receipt> execute(ReceiptId receiptId) async {
    final receipt = await _receiptRepository.getById(receiptId);
    if (receipt.status == ReceiptStatus.pending ||
        receipt.status == ReceiptStatus.processing) {
      throw ConflictException(
        'Receipt "${receiptId.value}" already has a running extraction.',
      );
    }

    final requestId = ExtractRequestId.create();
    await _receiptRepository.replacePendingExtraction(
      receiptId: receiptId,
      requestId: requestId,
    );
    _extractionJobDispatcher.schedule(receiptId);
    return _receiptRepository.getById(receiptId);
  }
}
