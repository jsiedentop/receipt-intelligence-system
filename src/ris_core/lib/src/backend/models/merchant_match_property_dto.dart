class MerchantMatchPropertyDto {
  const MerchantMatchPropertyDto({
    required this.id,
    required this.propertyType,
    required this.propertyValueRaw,
    required this.propertyValueNormalized,
  });

  final int id;
  final String propertyType;
  final String propertyValueRaw;
  final String propertyValueNormalized;

  factory MerchantMatchPropertyDto.fromJson(Map<String, dynamic> json) {
    return MerchantMatchPropertyDto(
      id: json['id'] as int,
      propertyType: json['propertyType'] as String,
      propertyValueRaw: json['propertyValueRaw'] as String,
      propertyValueNormalized: json['propertyValueNormalized'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'propertyType': propertyType,
      'propertyValueRaw': propertyValueRaw,
      'propertyValueNormalized': propertyValueNormalized,
    };
  }
}
