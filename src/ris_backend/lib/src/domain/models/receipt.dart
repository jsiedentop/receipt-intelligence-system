import 'package:ris_core/ris_core.dart';

import 'merchant_match.dart';
import 'merchant.dart';

class Receipt {
  const Receipt({
    required this.id,
    required this.createdAt,
    required this.status,
    required this.image,
    required this.extractRequestId,
    required this.merchantId,
    required this.merchant,
    required this.merchantAssignedType,
    required this.itemsCurrency,
    required this.items,
    required this.validationWarnings,
    required this.extraction,
  });

  final ReceiptId id;
  final DateTime createdAt;
  final ReceiptStatus status;
  final StoredReceiptImage image;
  final ExtractRequestId extractRequestId;
  final MerchantId? merchantId;
  final Merchant? merchant;
  final MerchantAssignedType? merchantAssignedType;
  final String? itemsCurrency;
  final List<ReceiptItem> items;
  final List<ReceiptValidationWarning> validationWarnings;
  final ReceiptExtraction? extraction;

  Map<String, Object?> toJson() {
    return {
      'id': id.value,
      'createdAt': createdAt.toIso8601String(),
      'status': status.name,
      'image': image.toJson(),
      'extractRequestId': extractRequestId.value,
      'merchantId': merchantId?.value,
      'merchant': merchant?.toJson(),
      'merchantAssignedType': merchantAssignedType?.name,
      'itemsCurrency': itemsCurrency,
      'items': items.map((item) => item.toJson()).toList(growable: false),
      'validationWarnings': validationWarnings
          .map((warning) => warning.toJson())
          .toList(growable: false),
      'extraction': extraction?.toJson(),
    };
  }
}

enum ReceiptStatus { pending, processing, processed, failed }

class ReceiptItem {
  const ReceiptItem({
    required this.id,
    required this.itemNumber,
    required this.name,
    required this.totalPrice,
    required this.quantity,
    required this.category,
  });

  final String id;
  final String? itemNumber;
  final String? name;
  final double? totalPrice;
  final int? quantity;
  final ReceiptItemCategory? category;

  Map<String, Object?> toJson() {
    return {
      'id': id,
      'itemNumber': itemNumber,
      'name': name,
      'totalPrice': totalPrice,
      'quantity': quantity,
      'category': category?.apiValue,
    };
  }
}

class ReceiptValidationWarning {
  const ReceiptValidationWarning({required this.code, required this.message});

  final String code;
  final String message;

  Map<String, Object?> toJson() {
    return {'code': code, 'message': message};
  }
}

class StoredReceiptImage {
  const StoredReceiptImage({
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

  Map<String, Object?> toJson() {
    return {
      'originalFileName': originalFileName,
      'mimeType': mimeType,
      'storagePath': storagePath,
      'sha256': sha256,
      'sizeBytes': sizeBytes,
    };
  }
}

class ReceiptExtraction {
  const ReceiptExtraction({
    required this.requestId,
    required this.rawText,
    required this.ocrData,
    required this.structuredData,
    required this.metadata,
    required this.warnings,
  });

  final ExtractRequestId requestId;
  final String rawText;
  final Map<String, dynamic> ocrData;
  final Map<String, dynamic> structuredData;
  final Map<String, dynamic> metadata;
  final List<Object?> warnings;

  Map<String, Object?> toJson() {
    return {
      'requestId': requestId.value,
      'rawText': rawText,
      'ocr': ocrData,
      'structured': structuredData,
      'metadata': metadata,
      'warnings': warnings,
    };
  }
}
