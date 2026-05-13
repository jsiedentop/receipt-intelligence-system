import 'package:ris_core/ris_core.dart';

import '../../domain/models/merchant.dart';

class MerchantResponseMapper {
  const MerchantResponseMapper();

  MerchantResponseDto toDto(Merchant merchant) {
    return MerchantResponseDto(
      id: merchant.id,
      name: merchant.name,
      street: merchant.street,
      postCode: merchant.postCode,
      city: merchant.city,
      taxId: merchant.taxId,
      matchProperties: merchant.matchProperties
          .map(
            (property) => MerchantMatchPropertyDto(
              id: property.id,
              propertyType: property.type.apiValue,
              propertyValueRaw: property.rawValue,
              propertyValueNormalized: property.normalizedValue,
            ),
          )
          .toList(growable: false),
    );
  }
}
