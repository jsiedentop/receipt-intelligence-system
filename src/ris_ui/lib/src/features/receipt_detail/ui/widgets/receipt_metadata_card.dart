import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:ris_core/ris_core.dart';

import '../../../../core/widgets/status_badge.dart';

class ReceiptMetadataCard extends StatelessWidget {
  const ReceiptMetadataCard({super.key, required this.receipt});

  final ReceiptResponseDto receipt;

  @override
  Widget build(BuildContext context) {
    final createdAt = DateFormat('yyyy-MM-dd HH:mm:ss').format(
      receipt.createdAt.toLocal(),
    );
    final extraction = receipt.extraction;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    receipt.image.originalFileName,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                ),
                StatusBadge(status: receipt.status),
              ],
            ),
            const SizedBox(height: 18),
            _MetadataRow(label: 'Receipt ID', value: receipt.id.value),
            _MetadataRow(label: 'Created at', value: createdAt),
            _MetadataRow(label: 'Extract request', value: receipt.extractRequestId.value),
            _MetadataRow(label: 'Mime type', value: receipt.image.mimeType),
            _MetadataRow(label: 'Storage path', value: receipt.image.storagePath),
            _MetadataRow(label: 'SHA-256', value: receipt.image.sha256),
            _MetadataRow(label: 'Size', value: '${receipt.image.sizeBytes} bytes'),
            if (extraction != null) ...[
              const Divider(height: 32),
              Text('Extraction', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 12),
              _MetadataRow(label: 'Request ID', value: extraction.requestId.value),
              _MetadataRow(label: 'Extractor', value: extraction.metadata.extractor),
              _MetadataRow(label: 'Version', value: extraction.metadata.version),
              _MetadataRow(label: 'Warnings', value: extraction.warnings.length.toString()),
              const SizedBox(height: 16),
              Text('Raw text', style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 8),
              SelectableText(extraction.rawText),
            ],
          ],
        ),
      ),
    );
  }
}

class _MetadataRow extends StatelessWidget {
  const _MetadataRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.labelMedium,
          ),
          const SizedBox(height: 4),
          SelectableText(value),
        ],
      ),
    );
  }
}
