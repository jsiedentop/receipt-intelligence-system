import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/widgets/app_shell.dart';
import '../../../core/widgets/status_badge.dart';
import '../../receipt_detail/ui/receipt_detail_screen.dart';
import '../../receipts_shared/ui/widgets/extraction_summary.dart';
import '../data/receipt_upload_repository.dart';
import '../logic/receipt_upload_controller.dart';

class ReceiptUploadScreen extends StatelessWidget {
  const ReceiptUploadScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<ReceiptUploadController>(
      create: (context) =>
          ReceiptUploadController(context.read<ReceiptUploadRepository>()),
      child: const _ReceiptUploadView(),
    );
  }
}

class _ReceiptUploadView extends StatelessWidget {
  const _ReceiptUploadView();

  @override
  Widget build(BuildContext context) {
    return Consumer<ReceiptUploadController>(
      builder: (context, controller, child) {
        final uploadedReceipt = controller.uploadedReceipt;

        return AppShell(
          title: 'Upload receipt',
          currentSection: AppSection.receipts,
          body: ListView(
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Upload a receipt image',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Choose a PNG or JPEG receipt image. The backend stores it immediately and processes extraction in the background.',
                      ),
                      const SizedBox(height: 20),
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: [
                          FilledButton.icon(
                            onPressed: controller.isPickingFile
                                ? null
                                : controller.pickFile,
                            icon: const Icon(Icons.folder_open),
                            label: Text(
                              controller.isPickingFile
                                  ? 'Opening...'
                                  : 'Choose file',
                            ),
                          ),
                          FilledButton.icon(
                            onPressed: controller.isUploading
                                ? null
                                : controller.upload,
                            icon: const Icon(Icons.cloud_upload),
                            label: Text(
                              controller.isUploading
                                  ? 'Uploading...'
                                  : 'Upload receipt',
                            ),
                          ),
                        ],
                      ),
                      if (controller.selectedFile != null) ...[
                        const SizedBox(height: 18),
                        Text('Selected file: ${controller.selectedFile!.name}'),
                        Text(
                          'Size: ${controller.selectedFile!.bytes.length} bytes',
                        ),
                      ],
                      if (controller.errorMessage != null) ...[
                        const SizedBox(height: 18),
                        Text(
                          controller.errorMessage!,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              if (uploadedReceipt != null) ...[
                const SizedBox(height: 16),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                'Upload status',
                                style: Theme.of(context).textTheme.titleLarge,
                              ),
                            ),
                            StatusBadge(status: uploadedReceipt.status),
                          ],
                        ),
                        const SizedBox(height: 16),
                        if (uploadedReceipt.status == 'pending' ||
                            uploadedReceipt.status == 'processing') ...[
                          const LinearProgressIndicator(),
                          const SizedBox(height: 12),
                          Text(
                            'Extraction is running in the background. This view updates automatically.',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ],
                        const SizedBox(height: 16),
                        Text('Receipt ID: ${uploadedReceipt.id.value}'),
                        Text(
                          'Request ID: ${uploadedReceipt.extractRequestId.value}',
                        ),
                        Text('Current status: ${uploadedReceipt.status}'),
                        if (uploadedReceipt.extraction != null) ...[
                          const SizedBox(height: 16),
                          Text(
                            'Structured extraction',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 8),
                          ExtractionSummary(
                            extraction: uploadedReceipt.extraction!,
                          ),
                        ],
                        const SizedBox(height: 20),
                        FilledButton.icon(
                          onPressed: () {
                            Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (_) => ReceiptDetailScreen(
                                  receiptId: uploadedReceipt.id.value,
                                ),
                              ),
                            );
                          },
                          icon: const Icon(Icons.open_in_new),
                          label: const Text('Open detail view'),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}
