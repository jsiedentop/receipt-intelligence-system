import 'package:ris_core/ris_core.dart';

import 'merchant.dart';
import 'receipt.dart';

enum MerchantAssignedType { auto, manual, unmatched }

enum MerchantMatchPropertyType {
  merchantName(apiValue: 'merchant_name', weight: 40),
  street(apiValue: 'street', weight: 25),
  postCode(apiValue: 'post_code', weight: 8),
  city(apiValue: 'city', weight: 5),
  taxId(apiValue: 'tax_id', weight: 100),
  tseSerialNumber(apiValue: 'tse_serial_number', weight: 90);

  const MerchantMatchPropertyType({
    required this.apiValue,
    required this.weight,
  });

  final String apiValue;
  final int weight;

  static MerchantMatchPropertyType fromApiValue(String value) {
    return MerchantMatchPropertyType.values.firstWhere(
      (type) => type.apiValue == value,
    );
  }
}

class MerchantMatchProperty {
  const MerchantMatchProperty({
    required this.type,
    required this.rawValue,
    required this.normalizedValue,
  });

  final MerchantMatchPropertyType type;
  final String rawValue;
  final String normalizedValue;
}

class MerchantStoredMatchProperty {
  const MerchantStoredMatchProperty({
    required this.id,
    required this.type,
    required this.rawValue,
    required this.normalizedValue,
  });

  final int id;
  final MerchantMatchPropertyType type;
  final String rawValue;
  final String normalizedValue;
}

class MerchantCandidateScore {
  const MerchantCandidateScore({required this.merchantId, required this.score});

  final MerchantId merchantId;
  final double score;
}

class MerchantCandidate {
  const MerchantCandidate({required this.merchant, required this.score});

  final Merchant merchant;
  final double score;
}

final double merchantMatchMaximumScore = MerchantMatchPropertyType.values
    .fold<int>(0, (sum, type) => sum + type.weight)
    .toDouble();

List<MerchantMatchProperty> extractMerchantMatchProperties(
  ReceiptExtraction? extraction,
) {
  if (extraction == null) {
    return const <MerchantMatchProperty>[];
  }

  final structured = extraction.structuredData;
  final merchantInfo = structured['merchantInfo'];
  final qrcodeTseData = structured['qrcode_tse_data'];
  final parsedQrcodeTseData = qrcodeTseData is Map ? qrcodeTseData['parsed'] : null;

  final properties = <MerchantMatchProperty>[];
  _addProperty(
    properties,
    MerchantMatchPropertyType.merchantName,
    merchantInfo is Map ? merchantInfo['merchant_name'] : null,
  );
  _addProperty(
    properties,
    MerchantMatchPropertyType.street,
    merchantInfo is Map ? merchantInfo['street'] : null,
  );
  _addProperty(
    properties,
    MerchantMatchPropertyType.postCode,
    merchantInfo is Map ? merchantInfo['post_code'] : null,
  );
  _addProperty(
    properties,
    MerchantMatchPropertyType.city,
    merchantInfo is Map ? merchantInfo['city'] : null,
  );
  _addProperty(
    properties,
    MerchantMatchPropertyType.taxId,
    merchantInfo is Map ? merchantInfo['ustid'] : null,
  );
  _addProperty(
    properties,
    MerchantMatchPropertyType.tseSerialNumber,
    merchantInfo is Map ? merchantInfo['tse_serial_number'] : null,
  );
  _addProperty(
    properties,
    MerchantMatchPropertyType.tseSerialNumber,
    parsedQrcodeTseData is Map ? parsedQrcodeTseData['tss_serial_number'] : null,
  );

  return deduplicateMerchantMatchProperties(properties);
}

List<MerchantMatchProperty> deduplicateMerchantMatchProperties(
  List<MerchantMatchProperty> properties,
) {
  final seenKeys = <String>{};
  final deduplicated = <MerchantMatchProperty>[];
  for (final property in properties) {
    final key = '${property.type.apiValue}:${property.normalizedValue}';
    if (seenKeys.add(key)) {
      deduplicated.add(property);
    }
  }

  return deduplicated;
}

void _addProperty(
  List<MerchantMatchProperty> properties,
  MerchantMatchPropertyType type,
  Object? rawValue,
) {
  if (rawValue is! String) {
    return;
  }

  final trimmed = rawValue.trim();
  if (trimmed.isEmpty) {
    return;
  }

  final normalized = normalizeMerchantMatchValue(type, trimmed);
  if (normalized == null) {
    return;
  }

  properties.add(
    MerchantMatchProperty(
      type: type,
      rawValue: trimmed,
      normalizedValue: normalized,
    ),
  );
}

String? normalizeMerchantMatchValue(
  MerchantMatchPropertyType type,
  String? value,
) {
  if (value == null) {
    return null;
  }

  final trimmed = value.trim();
  if (trimmed.isEmpty) {
    return null;
  }

  return switch (type) {
    MerchantMatchPropertyType.taxId ||
    MerchantMatchPropertyType.tseSerialNumber => _normalizeCompact(trimmed),
    MerchantMatchPropertyType.postCode => _normalizeDigits(trimmed),
    MerchantMatchPropertyType.merchantName ||
    MerchantMatchPropertyType.street ||
    MerchantMatchPropertyType.city => _normalizeText(trimmed),
  };
}

String? _normalizeCompact(String value) {
  final normalized = _replaceGermanCharacters(value).toUpperCase().replaceAll(
    RegExp(r'[^A-Z0-9]'),
    '',
  );
  return normalized.isEmpty ? null : normalized;
}

String? _normalizeDigits(String value) {
  final normalized = value.replaceAll(RegExp(r'\D'), '');
  return normalized.isEmpty ? null : normalized;
}

String? _normalizeText(String value) {
  var normalized = _replaceGermanCharacters(value).toLowerCase();
  normalized = normalized.replaceAll(RegExp(r'[^a-z0-9]+'), ' ');
  normalized = normalized.replaceAll(RegExp(r'\s+'), ' ').trim();
  return normalized.isEmpty ? null : normalized;
}

String _replaceGermanCharacters(String value) {
  return value
      .replaceAll('Ä', 'Ae')
      .replaceAll('Ö', 'Oe')
      .replaceAll('Ü', 'Ue')
      .replaceAll('ä', 'ae')
      .replaceAll('ö', 'oe')
      .replaceAll('ü', 'ue')
      .replaceAll('ß', 'ss');
}
