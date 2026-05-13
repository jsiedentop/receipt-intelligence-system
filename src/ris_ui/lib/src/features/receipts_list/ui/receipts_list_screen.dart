import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../app/router.dart';
import '../../../core/widgets/app_async_view.dart';
import '../../../core/widgets/app_empty_state.dart';
import '../../../core/widgets/app_shell.dart';
import '../data/receipts_list_repository.dart';
import '../logic/receipts_list_controller.dart';
import 'widgets/receipt_list_item.dart';

class ReceiptsListScreen extends StatelessWidget {
  const ReceiptsListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<ReceiptsListController>(
      create: (context) =>
          ReceiptsListController(context.read<ReceiptsListRepository>())
            ..loadInitial(),
      child: const _ReceiptsListView(),
    );
  }
}

class _ReceiptsListView extends StatelessWidget {
  const _ReceiptsListView();

  @override
  Widget build(BuildContext context) {
    return Consumer<ReceiptsListController>(
      builder: (context, controller, child) {
        return AppShell(
          title: 'Receipts',
          currentSection: AppSection.receipts,
          actions: [
            IconButton(
              tooltip: 'Refresh',
              onPressed: controller.refresh,
              icon: const Icon(Icons.refresh),
            ),
            const SizedBox(width: 8),
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: FilledButton.icon(
                onPressed: () async {
                  await Navigator.of(context).pushNamed(AppRoutePaths.upload);
                  if (context.mounted) {
                    await controller.refresh();
                  }
                },
                icon: const Icon(Icons.upload_file),
                label: const Text('Upload'),
              ),
            ),
          ],
          body: AppAsyncView(
            isLoading: controller.isInitialLoading,
            errorMessage: controller.errorMessage,
            onRetry: controller.loadInitial,
            child: controller.receipts.isEmpty
                ? AppEmptyState(
                    title: 'No receipts yet',
                    message:
                        'Upload your first receipt to start managing extraction results.',
                    action: FilledButton.icon(
                      onPressed: () =>
                          Navigator.of(context).pushNamed(AppRoutePaths.upload),
                      icon: const Icon(Icons.upload_file),
                      label: const Text('Upload receipt'),
                    ),
                  )
                : Column(
                    children: [
                      Expanded(
                        child: ListView.separated(
                          itemCount: controller.receipts.length,
                          separatorBuilder: (_, _) =>
                              const SizedBox(height: 12),
                          itemBuilder: (context, index) {
                            final receipt = controller.receipts[index];
                            return ReceiptListItem(
                              receipt: receipt,
                              onTap: () async {
                                await Navigator.of(
                                  context,
                                ).pushNamed('/receipts/${receipt.id.value}');
                                if (context.mounted) {
                                  await controller.refresh();
                                }
                              },
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 16),
                      if (controller.hasMore)
                        FilledButton(
                          onPressed: controller.isLoadingMore
                              ? null
                              : controller.loadMore,
                          child: controller.isLoadingMore
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Text('Load more'),
                        ),
                    ],
                  ),
          ),
        );
      },
    );
  }
}
