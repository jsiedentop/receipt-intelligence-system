import 'package:flutter/material.dart';
import 'package:ris_core/ris_core.dart';

import 'editable_receipt_item_card.dart';

class ReceiptItemsCard extends StatelessWidget {
  const ReceiptItemsCard({
    super.key,
    required this.receipt,
    required this.isUpdatingItem,
    required this.onSaveItem,
  });

  final ReceiptResponseDto receipt;
  final bool Function(String itemId) isUpdatingItem;
  final ReceiptItemSaveCallback onSaveItem;

  @override
  Widget build(BuildContext context) {
    final extractedLineItems = receipt.extraction?.structured.lineItems;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Receipt items',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            _ReceiptItemsValue(
              label: 'Currency',
              value: receipt.itemsCurrency ?? 'Unknown',
            ),
            if (extractedLineItems != null) ...[
              _ReceiptItemsValue(
                label: 'Detected items',
                value: extractedLineItems.items.length.toString(),
              ),
              if (extractedLineItems.totalAmount != null)
                _ReceiptItemsValue(
                  label: 'Structured total amount',
                  value: _formatAmount(
                    extractedLineItems.totalAmount,
                    extractedLineItems.currency,
                  ),
                ),
            ],
            if (receipt.items.isEmpty)
              Text(
                'No persisted receipt items available.',
                style: Theme.of(context).textTheme.bodyMedium,
              )
            else ...[
              const SizedBox(height: 8),
              ...receipt.items.asMap().entries.map(
                (entry) => EditableReceiptItemCard(
                  index: entry.key,
                  item: entry.value,
                  currency: receipt.itemsCurrency,
                  isSaving: isUpdatingItem(entry.value.id),
                  onSave: onSaveItem,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
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

class _ReceiptItemsValue extends StatelessWidget {
  const _ReceiptItemsValue({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.labelMedium),
          const SizedBox(height: 4),
          SelectableText(value),
        ],
      ),
    );
  }
}
