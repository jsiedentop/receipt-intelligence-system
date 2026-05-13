import 'package:ris_core/ris_core.dart';

class Merchant {
  const Merchant({
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

  Map<String, Object?> toJson() {
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
