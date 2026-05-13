import 'dart:convert';

+import 'package:flutter/material.dart';
+import 'package:intl/intl.dart';
+import 'package:ris_core/ris_core.dart';
+
+class ReceiptMetadataCard extends StatefulWidget {
+  const ReceiptMetadataCard({super.key, required this.receipt});
+
+  final ReceiptResponseDto receipt;
+
+  @override
+  State<ReceiptMetadataCard> createState() => _ReceiptMetadataCardState();
+}
+
+class _ReceiptMetadataCardState extends State<ReceiptMetadataCard> {
+  bool _isExpanded = true;
+
+  @override
+  Widget build(BuildContext context) {
+    final createdAt = DateFormat(
+      'yyyy-MM-dd HH:mm:ss',
+    ).format(widget.receipt.createdAt.toLocal());
+    final extraction = widget.receipt.extraction;
+    final structured = extraction?.structured;
+    final merchantInfo = structured?.merchantInfo;
+    final tseQr = structured?.qrcodeTseData;
+
+    return Card(
+      clipBehavior: Clip.antiAlias,
+      child: Column(
+        crossAxisAlignment: CrossAxisAlignment.stretch,
+        children: [
+          InkWell(
+            onTap: () {
+              setState(() {
+                _isExpanded = !_isExpanded;
+              });
+            },
+            child: Padding(
+              padding: const EdgeInsets.all(20),
+              child: Row(
+                children: [
+                  Expanded(
+                    child: Text(
+                      'Metadata',
+                      style: Theme.of(context).textTheme.titleMedium,
+                    ),
+                  ),
+                  Icon(_isExpanded ? Icons.expand_less : Icons.expand_more),
+                ],
+              ),
+            ),
+          ),
+          if (_isExpanded)
+            Padding(
+              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
+              child: Column(
+                crossAxisAlignment: CrossAxisAlignment.start,
+                children: [
+                  _MetadataRow(
+                    label: 'Receipt ID',
+                    value: widget.receipt.id.value,
+                  ),
+                  _MetadataRow(label: 'Created at', value: createdAt),
+                  _MetadataRow(
+                    label: 'Extract request',
+                    value: widget.receipt.extractRequestId.value,
+                  ),
+                  _MetadataRow(
+                    label: 'Mime type',
+                    value: widget.receipt.image.mimeType,
+                  ),
+                  _MetadataRow(
+                    label: 'Storage path',
+                    value: widget.receipt.image.storagePath,
+                  ),
+                  _MetadataRow(
+                    label: 'SHA-256',
+                    value: widget.receipt.image.sha256,
+                  ),
+                  _MetadataRow(
+                    label: 'Size',
+                    value: '${widget.receipt.image.sizeBytes} bytes',
+                  ),
+                  if (extraction != null) ...[
+                    const Divider(height: 32),
+                    Text(
+                      'Extraction',
+                      style: Theme.of(context).textTheme.titleMedium,
+                    ),
+                    const SizedBox(height: 12),
+                    _MetadataRow(
+                      label: 'Request ID',
+                      value: extraction.requestId.value,
+                    ),
+                    _MetadataRow(
+                      label: 'Extractor',
+                      value: extraction.metadata.extractor,
+                    ),
+                    _MetadataRow(
+                      label: 'Version',
+                      value: extraction.metadata.version,
+                    ),
+                    if (extraction.metadata.models.llm != null)
+                      _MetadataRow(
+                        label: 'LLM model',
+                        value:
+                            '${extraction.metadata.models.llm!.provider} '
+                            '${extraction.metadata.models.llm!.model}',
+                      ),
+                    _MetadataRow(
+                      label: 'Warnings',
+                      value: extraction.warnings.length.toString(),
+                    ),
+                    if (extraction.warnings.isNotEmpty) ...[
+                      const SizedBox(height: 12),
+                      Text(
+                        'Warnings',
+                        style: Theme.of(context).textTheme.titleSmall,
+                      ),
+                      const SizedBox(height: 8),
+                      ...extraction.warnings.asMap().entries.map(
+                        (entry) => _MetadataRow(
+                          label: 'Warning ${entry.key + 1}',
+                          value: _formatWarning(entry.value),
+                        ),
+                      ),
+                    ],
+                    if (merchantInfo != null) ...[
+                      const SizedBox(height: 12),
+                      Text(
+                        'Merchant info',
+                        style: Theme.of(context).textTheme.titleSmall,
+                      ),
+                      const SizedBox(height: 8),
+                      ..._buildOptionalRows([
+                        ('Merchant name', merchantInfo.merchantName),
+                        ('Street', merchantInfo.street),
+                        ('Post code', merchantInfo.postCode),
+                        ('City', merchantInfo.city),
+                        ('UST-ID', merchantInfo.ustid),
+                        ('TSE serial number', merchantInfo.tseSerialNumber),
+                        ('Date/time', merchantInfo.dateTime),
+                      ]),
+                    ],
+                    if (tseQr != null) ...[
+                      const SizedBox(height: 12),
+                      Text(
+                        'TSE QR data',
+                        style: Theme.of(context).textTheme.titleSmall,
+                      ),
+                      const SizedBox(height: 8),
+                      _MetadataRow(label: 'Format', value: tseQr.format),
+                      _MetadataRow(
+                        label: 'TSE QR',
+                        value: tseQr.isTseQr ? 'Yes' : 'No',
+                      ),
+                      if (tseQr.parsed != null) ...[
+                        ..._buildRequiredRows([
+                          ('Version', tseQr.parsed!.version),
+                          ('TSS serial number', tseQr.parsed!.tssSerialNumber),
+                          ('Receipt type', tseQr.parsed!.receiptType),
+                          ('Process data', tseQr.parsed!.processData),
+                          (
+                            'Transaction number',
+                            tseQr.parsed!.transactionNumber,
+                          ),
+                          (
+                            'Signature counter',
+                            tseQr.parsed!.signatureCounter,
+                          ),
+                          ('Time start', tseQr.parsed!.timeStart),
+                          ('Time end', tseQr.parsed!.timeEnd),
+                          (
+                            'Signature algorithm',
+                            tseQr.parsed!.signatureAlgorithm,
+                          ),
+                          ('Timestamp format', tseQr.parsed!.timestampFormat),
+                          ('Signature', tseQr.parsed!.signature),
+                          ('Public key', tseQr.parsed!.publicKey),
+                        ]),
+                      ],
+                      _MetadataRow(label: 'Raw payload', value: tseQr.rawText),
+                    ],
+                    const SizedBox(height: 16),
+                    Text(
+                      'Raw text',
+                      style: Theme.of(context).textTheme.titleSmall,
+                    ),
+                    const SizedBox(height: 8),
+                    SelectableText(extraction.rawText),
+                  ],
+                ],
+              ),
+            ),
+        ],
+      ),
+    );
+  }
+}
+
+Iterable<Widget> _buildOptionalRows(List<(String, String?)> entries) sync* {
+  for (final entry in entries) {
+    if (entry.$2 != null && entry.$2!.isNotEmpty) {
+      yield _MetadataRow(label: entry.$1, value: entry.$2!);
+    }
+  }
+}
+
+Iterable<Widget> _buildRequiredRows(List<(String, String)> entries) sync* {
+  for (final entry in entries) {
+    yield _MetadataRow(label: entry.$1, value: entry.$2);
+  }
+}
+
+String _formatWarning(Object? warning) {
+  if (warning == null) {
+    return 'null';
+  }
+
+  if (warning is String) {
+    return warning;
+  }
+
+  try {
+    return const JsonEncoder.withIndent('  ').convert(warning);
+  } catch (_) {
+    return warning.toString();
+  }
+}
+
+class _MetadataRow extends StatelessWidget {
+  const _MetadataRow({required this.label, required this.value});
+
+  final String label;
+  final String value;
+
+  @override
+  Widget build(BuildContext context) {
+    return Padding(
+      padding: const EdgeInsets.only(bottom: 10),
+      child: Column(
+        crossAxisAlignment: CrossAxisAlignment.start,
+        children: [
+          Text(label, style: Theme.of(context).textTheme.labelMedium),
+          const SizedBox(height: 4),
+          SelectableText(value),
+        ],
+      ),
+    );
+  }
+}
