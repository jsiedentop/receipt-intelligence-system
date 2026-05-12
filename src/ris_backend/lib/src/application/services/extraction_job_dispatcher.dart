import 'package:ris_core/ris_core.dart';

abstract interface class ExtractionJobDispatcher {
  void schedule(ReceiptId receiptId);

  Future<void> recoverPendingJobs();
}
