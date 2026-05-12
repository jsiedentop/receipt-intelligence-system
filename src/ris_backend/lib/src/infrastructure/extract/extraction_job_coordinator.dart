import 'dart:async';
import 'dart:collection';

import 'package:ris_core/ris_core.dart';

import '../../application/services/extraction_job_dispatcher.dart';
import '../../application/use_cases/process_receipt_extraction.dart';
import '../../domain/models/receipt.dart';
import '../../domain/repositories/receipt_repository.dart';

class ExtractionJobCoordinator implements ExtractionJobDispatcher {
  ExtractionJobCoordinator({
    required ReceiptRepository receiptRepository,
    required ProcessReceiptExtractionUseCase processReceiptExtractionUseCase,
  }) : _receiptRepository = receiptRepository,
       _processReceiptExtractionUseCase = processReceiptExtractionUseCase;

  final ReceiptRepository _receiptRepository;
  final ProcessReceiptExtractionUseCase _processReceiptExtractionUseCase;
  final Queue<ReceiptId> _queue = Queue<ReceiptId>();
  final Set<String> _scheduledReceiptIds = <String>{};
  bool _isProcessing = false;

  @override
  void schedule(ReceiptId receiptId) {
    if (_scheduledReceiptIds.add(receiptId.value)) {
      _queue.add(receiptId);
    }
    unawaited(_drainQueue());
  }

  @override
  Future<void> recoverPendingJobs() async {
    final receipts = await _receiptRepository.listByStatuses([
      ReceiptStatus.pending,
      ReceiptStatus.processing,
    ]);
    for (final receipt in receipts) {
      schedule(receipt.id);
    }
  }

  Future<void> _drainQueue() async {
    if (_isProcessing) {
      return;
    }

    _isProcessing = true;
    try {
      while (_queue.isNotEmpty) {
        final receiptId = _queue.removeFirst();
        try {
          await _processReceiptExtractionUseCase.execute(receiptId);
        } finally {
          _scheduledReceiptIds.remove(receiptId.value);
        }
      }
    } finally {
      _isProcessing = false;
    }
  }
}
