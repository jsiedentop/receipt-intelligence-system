import 'package:ris_core/ris_core.dart';

import '../../domain/models/merchant_match.dart';
import '../../domain/repositories/merchant_repository.dart';
import '../../domain/repositories/receipt_repository.dart';

class FindReceiptMerchantCandidatesUseCase {
  const FindReceiptMerchantCandidatesUseCase({
    required ReceiptRepository receiptRepository,
    required MerchantRepository merchantRepository,
  }) : _receiptRepository = receiptRepository,
       _merchantRepository = merchantRepository;

  final ReceiptRepository _receiptRepository;
  final MerchantRepository _merchantRepository;

  Future<List<MerchantCandidate>> execute(ReceiptId receiptId) async {
    final receipt = await _receiptRepository.getById(receiptId);
    final properties = extractMerchantMatchProperties(receipt.extraction);
    final scores = await _receiptRepository.scoreMerchantCandidates(properties);

    final candidates = <MerchantCandidate>[];
    for (final score in scores) {
      final merchant = await _merchantRepository.getById(score.merchantId);
      candidates.add(MerchantCandidate(merchant: merchant, score: score.score));
    }

    return candidates;
  }
}
