import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:ris_core/ris_core.dart';

import '../../../../core/widgets/status_badge.dart';

class ReceiptListItem extends StatelessWidget {
  const ReceiptListItem({
    super.key,
    required this.receipt,
    required this.onTap,
  });

  final ReceiptResponseDto receipt;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final receiptDate = receipt.extraction?.structured.merchantInfo?.dateTime;
    final displayDate = _formatDisplayDate(receiptDate, receipt.createdAt);
    final dateLabel = receiptDate == null || receiptDate.trim().isEmpty
        ? '(created)'
        : '';

    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Text(
                          receipt.image.originalFileName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(
                            '$displayDate $dateLabel',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: StatusBadge(status: receipt.status),
                  ),
                ],
              ),
              if (receipt.validationWarnings.isNotEmpty) ...[
                const SizedBox(height: 12),
                ...receipt.validationWarnings.map(
                  (warning) => _ReceiptWarningRow(message: warning.message),
                ),
              ],
              const SizedBox(height: 12),
              if (receipt.merchant == null)
                const _ReceiptWarningRow(message: 'No merchant assigned.')
              else
                Text(
                  'Merchant: ${receipt.merchant!.name}',
                  style: theme.textTheme.bodyMedium,
                ),
              const SizedBox(height: 12),
              if (receipt.items.isEmpty)
                Text('No items available.', style: theme.textTheme.bodySmall)
              else
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: receipt.items
                      .map(
                        (item) => Chip(
                          label: Text(
                            _formatItemBadge(item, receipt.itemsCurrency),
                          ),
                        ),
                      )
                      .toList(growable: false),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ReceiptWarningRow extends StatelessWidget {
  const _ReceiptWarningRow({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.warning_amber_rounded,
            size: 18,
            color: theme.colorScheme.error,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

String _formatDisplayDate(String? receiptDate, DateTime createdAt) {
  if (receiptDate != null && receiptDate.trim().isNotEmpty) {
    final parsed = DateTime.tryParse(receiptDate.trim());
    if (parsed != null) {
      return DateFormat('yyyy-MM-dd HH:mm').format(parsed.toLocal());
    }

    return receiptDate.trim();
  }

  return DateFormat('yyyy-MM-dd HH:mm').format(createdAt.toLocal());
}

String _formatItemBadge(ReceiptItemDto item, String? currency) {
  final parts = <String>[
    item.name?.trim().isNotEmpty == true ? item.name!.trim() : 'Unnamed item',
  ];

  if (item.totalPrice != null) {
    final amount = item.totalPrice!.toStringAsFixed(2);
    parts.add(
      currency == null || currency.isEmpty ? amount : '$amount $currency',
    );
  }
  if (item.category != null) {
    parts.add(item.category!.apiValue);
  }

  return parts.join(' • ');
}
