import 'package:ris_core/ris_core.dart';

import '../../domain/models/receipt.dart';

class ReceiptResponseMapper {
  const ReceiptResponseMapper();

  // This mapping is currently only a complete pass-through and doesn't show
  // the benefit of having a separate DTO layer, as the ReceiptResponseDto
  // is almost identical to the Receipt model. This is mostly because we show
  // all kind of metadata and details in the UI, but in a real world scenario,
  // we would deliver only the necessary data to the client and keep internal
  // details hidden. We could consider to create a new analytics/admin endpoint
  // for the details we would remove from the mapping here.

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
                matchProperties: receipt.merchant!.matchProperties
                    .map(
                      (property) => MerchantMatchPropertyDto(
                        id: property.id,
                        propertyType: property.type.apiValue,
                        propertyValueRaw: property.rawValue,
                        propertyValueNormalized: property.normalizedValue,
                      ),
                    )
                    .toList(growable: false),
              ),
      merchantAssignedType: receipt.merchantAssignedType == null
          ? null
          : MerchantAssignedTypeDto.values.byName(
              receipt.merchantAssignedType!.name,
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
