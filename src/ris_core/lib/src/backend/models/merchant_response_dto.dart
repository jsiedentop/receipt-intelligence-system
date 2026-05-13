import '../../ids/merchant_id.dart';

class MerchantResponseDto {
  const MerchantResponseDto({
    required this.id,
    required this.name,
    required this.street,
    required this.postCode,
    required this.city,
    required this.taxId,
  });

  final MerchantId id;
  final String name;
  final String street;
  final String postCode;
  final String city;
  final String taxId;

  factory MerchantResponseDto.fromJson(Map<String, dynamic> json) {
    return MerchantResponseDto(
      id: MerchantId(json['id'] as String),
      name: json['name'] as String,
      street: json['street'] as String,
      postCode: json['postCode'] as String,
      city: json['city'] as String,
      taxId: json['taxId'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id.value,
      'name': name,
      'street': street,
      'postCode': postCode,
      'city': city,
      'taxId': taxId,
    };
  }
}
