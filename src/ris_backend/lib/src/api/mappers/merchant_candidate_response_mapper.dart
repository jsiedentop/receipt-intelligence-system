import 'package:ris_core/ris_core.dart';

import '../../domain/models/merchant_match.dart';

class MerchantCandidateResponseMapper {
  const MerchantCandidateResponseMapper();

  MerchantCandidateDto toDto(MerchantCandidate candidate) {
    return MerchantCandidateDto(
      merchantId: candidate.merchant.id,
      score: candidate.score,
      merchant: MerchantResponseDto(
        id: candidate.merchant.id,
        name: candidate.merchant.name,
        street: candidate.merchant.street,
        postCode: candidate.merchant.postCode,
        city: candidate.merchant.city,
        taxId: candidate.merchant.taxId,
        matchProperties: const <MerchantMatchPropertyDto>[],
      ),
    );
  }
}
