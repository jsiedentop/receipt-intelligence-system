import 'package:ris_core/ris_core.dart';

import '../../domain/models/receipt.dart';

class ReceiptResponseMapper {
  const ReceiptResponseMapper();

  ReceiptResponseDto toDto(Receipt receipt) {
    return ReceiptResponseDto(
      id: receipt.id,
      createdAt: receipt.createdAt,
      status: receipt.status.name,
      image: StoredReceiptImageDto(
        originalFileName: receipt.image.originalFileName,
        mimeType: receipt.image.mimeType,
        storagePath: receipt.image.storagePath,
        sha256: receipt.image.sha256,
        sizeBytes: receipt.image.sizeBytes,
      ),
      extractRequestId: receipt.extractRequestId,
      extraction: receipt.extraction == null
          ? null
          : ReceiptExtractionDto(
              requestId: receipt.extraction!.requestId,
              rawText: receipt.extraction!.rawText,
              ocr: ExtractOcr.fromJson(receipt.extraction!.ocrData),
              structured: ExtractStructured.fromJson(
                receipt.extraction!.structuredData,
              ),
              metadata: ExtractMetadata.fromJson(receipt.extraction!.metadata),
              warnings: receipt.extraction!.warnings,
            ),
    );
  }
}
