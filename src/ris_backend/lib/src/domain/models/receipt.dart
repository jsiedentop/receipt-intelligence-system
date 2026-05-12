import 'package:ris_core/ris_core.dart';

class Receipt {
  const Receipt({
    required this.id,
    required this.createdAt,
    required this.status,
    required this.image,
    required this.extractRequestId,
    required this.extraction,
  });

  final ReceiptId id;
  final DateTime createdAt;
  final ReceiptStatus status;
  final StoredReceiptImage image;
  final ExtractRequestId extractRequestId;
  final ReceiptExtraction? extraction;

  Map<String, Object?> toJson() {
    return {
      'id': id.value,
      'createdAt': createdAt.toIso8601String(),
      'status': status.name,
      'image': image.toJson(),
      'extractRequestId': extractRequestId.value,
      'extraction': extraction?.toJson(),
    };
  }
}

enum ReceiptStatus { pending, processing, processed, failed }

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
    required this.metadata,
    required this.warnings,
  });

  final ExtractRequestId requestId;
  final String rawText;
  final Map<String, dynamic> ocrData;
  final Map<String, dynamic> metadata;
  final List<Object?> warnings;

  Map<String, Object?> toJson() {
    return {
      'requestId': requestId.value,
      'rawText': rawText,
      'ocr': ocrData,
      'metadata': metadata,
      'warnings': warnings,
    };
  }
}
