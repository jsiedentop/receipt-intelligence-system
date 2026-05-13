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
      merchantId: receipt.merchantId,
      merchant: receipt.merchant == null
          ? null
          : MerchantResponseDto(
              id: receipt.merchant!.id,
              name: receipt.merchant!.name,
              street: receipt.merchant!.street,
              postCode: receipt.merchant!.postCode,
              city: receipt.merchant!.city,
              taxId: receipt.merchant!.taxId,
            ),
      itemsCurrency: receipt.itemsCurrency,
      items: receipt.items
          .map(
            (item) => ReceiptItemDto(
              id: item.id,
              itemNumber: item.itemNumber,
              name: item.name,
              totalPrice: item.totalPrice,
              quantity: item.quantity,
              category: item.category,
            ),
          )
          .toList(growable: false),
      validationWarnings: receipt.validationWarnings
          .map(
            (warning) => ReceiptValidationWarningDto(
              code: warning.code,
              message: warning.message,
            ),
          )
          .toList(growable: false),
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
