import 'package:ris_core/ris_core.dart';

import 'merchant_match.dart';

class Merchant {
  const Merchant({
    required this.id,
    required this.name,
    required this.street,
    required this.postCode,
    required this.city,
    required this.taxId,
    this.matchProperties = const <MerchantStoredMatchProperty>[],
  });

  final MerchantId id;
  final String name;
  final String street;
  final String postCode;
  final String city;
  final String? taxId;
  final List<MerchantStoredMatchProperty> matchProperties;

  Map<String, Object?> toJson() {
    return {
      'id': id.value,
      'name': name,
      'street': street,
      'postCode': postCode,
      'city': city,
      'taxId': taxId,
      'matchProperties': matchProperties
          .map(
            (property) => {
              'id': property.id,
              'propertyType': property.type.apiValue,
              'propertyValueRaw': property.rawValue,
              'propertyValueNormalized': property.normalizedValue,
            },
          )
          .toList(growable: false),
    };
  }
}
