import 'dart:convert';

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
    final structured = extraction?.structured;
    final merchantInfo = structured?.merchantInfo;
    final lineItems = structured?.lineItems;
    final tseQr = structured?.qrcodeTseData;

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
              if (extraction.metadata.models.llm != null)
                _MetadataRow(
                  label: 'LLM model',
                  value: '${extraction.metadata.models.llm!.provider} '
                      '${extraction.metadata.models.llm!.model}',
                ),
              _MetadataRow(label: 'Warnings', value: extraction.warnings.length.toString()),
              if (extraction.warnings.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text('Warnings', style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 8),
                ...extraction.warnings.asMap().entries.map(
                  (entry) => _MetadataRow(
                    label: 'Warning ${entry.key + 1}',
                    value: _formatWarning(entry.value),
                  ),
                ),
              ],
              if (merchantInfo != null) ...[
                const SizedBox(height: 12),
                Text('Merchant info', style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 8),
                ..._buildOptionalRows([
                  ('Street', merchantInfo.street),
                  ('Post code', merchantInfo.postCode),
                  ('City', merchantInfo.city),
                  ('UST-ID', merchantInfo.ustid),
                  ('TSE serial number', merchantInfo.tseSerialNumber),
                  ('Date/time', merchantInfo.dateTime),
                ]),
              ],
              if (lineItems != null) ...[
                const SizedBox(height: 12),
                Text('Line items', style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 8),
                if (lineItems.totalAmount != null)
                  _MetadataRow(
                    label: 'Total amount',
                    value: _formatAmount(lineItems.totalAmount, lineItems.currency),
                  ),
                if (lineItems.currency != null)
                  _MetadataRow(label: 'Currency', value: lineItems.currency!),
                if (lineItems.items.isEmpty)
                  Text(
                    'No structured line items available.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  )
                else
                  ...lineItems.items.asMap().entries.map(
                    (entry) => _LineItemCard(
                      index: entry.key,
                      item: entry.value,
                      currency: lineItems.currency,
                    ),
                  ),
              ],
              if (tseQr != null) ...[
                const SizedBox(height: 12),
                Text('TSE QR data', style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 8),
                _MetadataRow(label: 'Format', value: tseQr.format),
                _MetadataRow(label: 'TSE QR', value: tseQr.isTseQr ? 'Yes' : 'No'),
                if (tseQr.parsed != null) ...[
                  ..._buildRequiredRows([
                    ('Version', tseQr.parsed!.version),
                    ('TSS serial number', tseQr.parsed!.tssSerialNumber),
                    ('Receipt type', tseQr.parsed!.receiptType),
                    ('Process data', tseQr.parsed!.processData),
                    ('Transaction number', tseQr.parsed!.transactionNumber),
                    ('Signature counter', tseQr.parsed!.signatureCounter),
                    ('Time start', tseQr.parsed!.timeStart),
                    ('Time end', tseQr.parsed!.timeEnd),
                    ('Signature algorithm', tseQr.parsed!.signatureAlgorithm),
                    ('Timestamp format', tseQr.parsed!.timestampFormat),
                    ('Signature', tseQr.parsed!.signature),
                    ('Public key', tseQr.parsed!.publicKey),
                  ]),
                ],
                _MetadataRow(label: 'Raw payload', value: tseQr.rawText),
              ],
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

Iterable<Widget> _buildOptionalRows(List<(String, String?)> entries) sync* {
  for (final entry in entries) {
    if (entry.$2 != null && entry.$2!.isNotEmpty) {
      yield _MetadataRow(label: entry.$1, value: entry.$2!);
    }
  }
}

Iterable<Widget> _buildRequiredRows(List<(String, String)> entries) sync* {
  for (final entry in entries) {
    yield _MetadataRow(label: entry.$1, value: entry.$2);
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

String _formatWarning(Object? warning) {
  if (warning == null) {
    return 'null';
  }

  if (warning is String) {
    return warning;
  }

  try {
    return const JsonEncoder.withIndent('  ').convert(warning);
  } catch (_) {
    return warning.toString();
  }
}

class _LineItemCard extends StatelessWidget {
  const _LineItemCard({
    required this.index,
    required this.item,
    required this.currency,
  });

  final int index;
  final ExtractLineItem item;
  final String? currency;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item.name?.isNotEmpty == true ? item.name! : 'Item ${index + 1}',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 8),
              ..._buildOptionalRows([
                ('Item number', item.itemNumber),
                ('Category', item.category),
              ]),
              if (item.quantity != null)
                _MetadataRow(label: 'Quantity', value: item.quantity.toString()),
              if (item.totalPrice != null)
                _MetadataRow(
                  label: 'Total price',
                  value: _formatAmount(item.totalPrice, currency),
                ),
            ],
          ),
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
