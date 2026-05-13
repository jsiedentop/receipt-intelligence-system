import 'package:flutter/material.dart';
import 'package:ris_core/ris_core.dart';

class ExtractionSummary extends StatelessWidget {
  const ExtractionSummary({
    super.key,
    required this.extraction,
    this.maxItems = 2,
    this.showRawTextPreview = true,
  });

  final ReceiptExtractionDto extraction;
  final int maxItems;
  final bool showRawTextPreview;

  @override
  Widget build(BuildContext context) {
    final merchantInfo = extraction.structured.merchantInfo;
    final lineItems = extraction.structured.lineItems;
    final tseQr = extraction.structured.qrcodeTseData;
    final previewItems = lineItems?.items.take(maxItems).toList(growable: false) ??
        const <ExtractLineItem>[];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (merchantInfo != null) ...[
          Text(
            _merchantSummary(merchantInfo),
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 6),
        ],
        if (lineItems != null) ...[
          Text(
            _lineItemsSummary(lineItems),
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          if (previewItems.isNotEmpty) ...[
            const SizedBox(height: 6),
            for (final item in previewItems)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  _lineItemLabel(item, lineItems.currency),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            if (lineItems.items.length > previewItems.length)
              Text(
                '+${lineItems.items.length - previewItems.length} more items',
                style: Theme.of(context).textTheme.bodySmall,
              ),
          ],
          const SizedBox(height: 6),
        ],
        if (tseQr != null)
          Text(
            tseQr.parsed == null
                ? 'TSE QR detected (${tseQr.format})'
                : 'TSE QR ${tseQr.parsed!.receiptType} ${tseQr.parsed!.transactionNumber}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        if (showRawTextPreview && extraction.rawText.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            extraction.rawText,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ],
    );
  }
}

String _merchantSummary(ExtractMerchantInfo merchantInfo) {
  final locationParts = [merchantInfo.postCode, merchantInfo.city]
      .whereType<String>()
      .where((value) => value.isNotEmpty)
      .join(' ');
  final parts = [merchantInfo.street, locationParts, merchantInfo.dateTime]
      .whereType<String>()
      .where((value) => value.isNotEmpty)
      .toList(growable: false);

  return parts.isEmpty ? 'Merchant info available' : parts.join(' | ');
}

String _lineItemsSummary(ExtractLineItems lineItems) {
  final count = '${lineItems.items.length} item${lineItems.items.length == 1 ? '' : 's'}';
  if (lineItems.totalAmount == null) {
    return count;
  }

  return '$count | Total ${_formatAmount(lineItems.totalAmount, lineItems.currency)}';
}

String _lineItemLabel(ExtractLineItem item, String? currency) {
  final name = item.name?.isNotEmpty == true ? item.name! : 'Unnamed item';
  final details = <String>[];

  if (item.quantity != null) {
    details.add('x${item.quantity}');
  }
  if (item.totalPrice != null) {
    details.add(_formatAmount(item.totalPrice, currency));
  }

  if (details.isEmpty) {
    return name;
  }

  return '$name (${details.join(', ')})';
}

String _formatAmount(double? amount, String? currency) {
  if (amount == null) {
    return 'Unknown';
  }

  final value = amount.toStringAsFixed(2);
  if (currency == null || currency.isEmpty) {
    return value;
  }

  return '$value $currency';
}
