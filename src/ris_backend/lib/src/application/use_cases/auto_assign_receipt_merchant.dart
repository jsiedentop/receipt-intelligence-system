import 'package:ris_core/ris_core.dart';

import '../../domain/models/merchant_match.dart';
import '../../domain/models/receipt.dart';
import '../../domain/repositories/receipt_repository.dart';

class AutoAssignReceiptMerchantUseCase {
  const AutoAssignReceiptMerchantUseCase({
    required ReceiptRepository receiptRepository,
    this.minimumScore = 0.25,
    this.minimumScoreGap = 0.05,
  }) : _receiptRepository = receiptRepository;

  final ReceiptRepository _receiptRepository;
  final double minimumScore;
  final double minimumScoreGap;

  Future<Receipt> execute(ReceiptId receiptId) async {
    final receipt = await _receiptRepository.getById(receiptId);
    if (receipt.merchantId != null) {
      return receipt;
    }

    final properties = extractMerchantMatchProperties(receipt.extraction);
    final scores = await _receiptRepository.scoreMerchantCandidates(properties);
    if (scores.isEmpty) {
      return receipt;
    }

    final bestCandidate = scores.first;
    if (bestCandidate.score < minimumScore) {
      return receipt;
    }

    if (scores.length > 1) {
      final secondBestCandidate = scores[1];
      final scoreGap = bestCandidate.score - secondBestCandidate.score;
      if (scoreGap < minimumScoreGap) {
        return receipt;
      }
    }

    await _receiptRepository.assignMerchant(
      receiptId: receiptId,
      merchantId: bestCandidate.merchantId,
      assignedType: MerchantAssignedType.auto,
    );
    await _receiptRepository.createMerchantMatchProperties(
      merchantId: bestCandidate.merchantId,
      properties: properties,
    );

    return _receiptRepository.getById(receiptId);
  }
}
