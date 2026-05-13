import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:ris_core/ris_core.dart';

import '../../../../core/widgets/status_badge.dart';
import '../../../receipts_shared/ui/widgets/extraction_summary.dart';

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
    final createdAt = DateFormat(
      'yyyy-MM-dd HH:mm',
    ).format(receipt.createdAt.toLocal());

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
                children: [
                  Expanded(
                    child: Text(
                      receipt.image.originalFileName,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  StatusBadge(status: receipt.status),
                ],
              ),
              const SizedBox(height: 10),
              Text('Created: $createdAt'),
              const SizedBox(height: 6),
              Text('Request: ${receipt.extractRequestId.value}'),
              const SizedBox(height: 6),
              Text('Mime type: ${receipt.image.mimeType}'),
              if (receipt.extraction != null) ...[
                const SizedBox(height: 12),
                ExtractionSummary(extraction: receipt.extraction!),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
