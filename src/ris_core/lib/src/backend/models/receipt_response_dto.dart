import 'merchant_response_dto.dart';
import 'receipt_item_dto.dart';
import '../../extract/extract_models.dart';
import '../../ids/extract_request_id.dart';
import '../../ids/merchant_id.dart';
import '../../ids/receipt_id.dart';

typedef BackendJsonMap = Map<String, dynamic>;

class ReceiptResponseDto {
  const ReceiptResponseDto({
    required this.id,
    required this.createdAt,
    required this.status,
    required this.image,
    required this.extractRequestId,
    required this.merchantId,
    required this.merchant,
    required this.itemsCurrency,
    required this.items,
    required this.validationWarnings,
    required this.extraction,
  });

  final ReceiptId id;
  final DateTime createdAt;
  final String status;
  final StoredReceiptImageDto image;
  final ExtractRequestId extractRequestId;
  final MerchantId? merchantId;
  final MerchantResponseDto? merchant;
  final String? itemsCurrency;
  final List<ReceiptItemDto> items;
  final List<ReceiptValidationWarningDto> validationWarnings;
  final ReceiptExtractionDto? extraction;

  factory ReceiptResponseDto.fromJson(BackendJsonMap json) {
    return ReceiptResponseDto(
      id: ReceiptId(json['id'] as String),
      createdAt: DateTime.parse(json['createdAt'] as String),
      status: json['status'] as String,
      image: StoredReceiptImageDto.fromJson(_asJsonMap(json['image'], 'image')),
      extractRequestId: ExtractRequestId(json['extractRequestId'] as String),
      merchantId: json['merchantId'] == null
          ? null
          : MerchantId(json['merchantId'] as String),
      merchant: json['merchant'] == null
          ? null
          : MerchantResponseDto.fromJson(
              _asJsonMap(json['merchant'], 'merchant'),
            ),
      itemsCurrency: json['itemsCurrency'] as String?,
      items: (json['items'] as List? ?? const <Object?>[])
          .map((item) => ReceiptItemDto.fromJson(_asJsonMap(item, 'items[]')))
          .toList(growable: false),
      validationWarnings:
          (json['validationWarnings'] as List? ?? const <Object?>[])
              .map(
                (warning) => ReceiptValidationWarningDto.fromJson(
                  _asJsonMap(warning, 'validationWarnings[]'),
                ),
              )
              .toList(growable: false),
      extraction: json['extraction'] == null
          ? null
          : ReceiptExtractionDto.fromJson(
              _asJsonMap(json['extraction'], 'extraction'),
            ),
    );
  }

  BackendJsonMap toJson() {
    return {
      'id': id.value,
      'createdAt': createdAt.toIso8601String(),
      'status': status,
      'image': image.toJson(),
      'extractRequestId': extractRequestId.value,
      'merchantId': merchantId?.value,
      'merchant': merchant?.toJson(),
      'itemsCurrency': itemsCurrency,
      'items': items.map((item) => item.toJson()).toList(growable: false),
      'validationWarnings': validationWarnings
          .map((warning) => warning.toJson())
          .toList(growable: false),
      'extraction': extraction?.toJson(),
    };
  }
}

class StoredReceiptImageDto {
  const StoredReceiptImageDto({
    required this.originalFileName,
    required this.mimeType,
    required this.storagePath,
    required this.sha256,
    required this.sizeBytes,
  });

  final String originalFileName;
  final String mimeType;
  final String storagePath;
  final String sha256;
  final int sizeBytes;

  factory StoredReceiptImageDto.fromJson(BackendJsonMap json) {
    return StoredReceiptImageDto(
      originalFileName: json['originalFileName'] as String,
      mimeType: json['mimeType'] as String,
      storagePath: json['storagePath'] as String,
      sha256: json['sha256'] as String,
      sizeBytes: json['sizeBytes'] as int,
    );
  }

  BackendJsonMap toJson() {
    return {
      'originalFileName': originalFileName,
      'mimeType': mimeType,
      'storagePath': storagePath,
      'sha256': sha256,
      'sizeBytes': sizeBytes,
    };
  }
}

class ReceiptExtractionDto {
  const ReceiptExtractionDto({
    required this.requestId,
    required this.rawText,
    required this.ocr,
    required this.structured,
    required this.metadata,
    required this.warnings,
  });

  final ExtractRequestId requestId;
  final String rawText;
  final ExtractOcr ocr;
  final ExtractStructured structured;
  final ExtractMetadata metadata;
  final List<Object?> warnings;

  factory ReceiptExtractionDto.fromJson(BackendJsonMap json) {
    return ReceiptExtractionDto(
      requestId: ExtractRequestId(json['requestId'] as String),
      rawText: json['rawText'] as String,
      ocr: ExtractOcr.fromJson(_asJsonMap(json['ocr'], 'ocr')),
      structured: ExtractStructured.fromJson(
        _asJsonMap(
          json['structured'] ?? const <String, Object?>{},
          'structured',
        ),
      ),
      metadata: ExtractMetadata.fromJson(
        _asJsonMap(json['metadata'], 'metadata'),
      ),
      warnings: List<Object?>.from(
        json['warnings'] as List? ?? const <Object?>[],
      ),
    );
  }

  BackendJsonMap toJson() {
    return {
      'requestId': requestId.value,
      'rawText': rawText,
      'ocr': ocr.toJson(),
      'structured': structured.toJson(),
      'metadata': metadata.toJson(),
      'warnings': warnings,
    };
  }
}

BackendJsonMap _asJsonMap(Object? value, String fieldName) {
  if (value is BackendJsonMap) {
    return value;
  }

  if (value is Map) {
    return value.map((key, entryValue) => MapEntry(key.toString(), entryValue));
  }

  throw FormatException('Expected $fieldName to be a JSON object.');
}
