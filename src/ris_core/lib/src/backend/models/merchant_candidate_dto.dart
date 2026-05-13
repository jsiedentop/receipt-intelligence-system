import 'merchant_response_dto.dart';
import '../../ids/merchant_id.dart';

class MerchantCandidateDto {
  const MerchantCandidateDto({
    required this.merchantId,
    required this.score,
    required this.merchant,
  });

  final MerchantId merchantId;
  final double score;
  final MerchantResponseDto merchant;

  factory MerchantCandidateDto.fromJson(Map<String, dynamic> json) {
    return MerchantCandidateDto(
      merchantId: MerchantId(json['merchantId'] as String),
      score: (json['score'] as num).toDouble(),
      merchant: MerchantResponseDto.fromJson(
        (json['merchant'] as Map).cast<String, dynamic>(),
      ),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'merchantId': merchantId.value,
      'score': score,
      'merchant': merchant.toJson(),
    };
  }
}
