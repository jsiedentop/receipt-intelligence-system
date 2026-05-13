import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../app/router.dart';
import '../../../core/widgets/app_async_view.dart';
import '../../../core/widgets/app_empty_state.dart';
import '../../../core/widgets/app_shell.dart';
import '../data/merchants_list_repository.dart';
import '../logic/merchants_list_controller.dart';

class MerchantsListScreen extends StatelessWidget {
  const MerchantsListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<MerchantsListController>(
      create: (context) =>
          MerchantsListController(context.read<MerchantsListRepository>())
            ..load(),
      child: const _MerchantsListView(),
    );
  }
}

class _MerchantsListView extends StatelessWidget {
  const _MerchantsListView();

  @override
  Widget build(BuildContext context) {
    return Consumer<MerchantsListController>(
      builder: (context, controller, child) {
        return AppShell(
          title: 'Merchants',
          currentSection: AppSection.merchants,
          actions: [
            IconButton(
              tooltip: 'Refresh',
              onPressed: controller.load,
              icon: const Icon(Icons.refresh),
            ),
            const SizedBox(width: 8),
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: FilledButton.icon(
                onPressed: () async {
                  await Navigator.of(
                    context,
                  ).pushNamed(AppRoutePaths.merchantCreate);
                  if (context.mounted) {
                    await controller.load();
                  }
                },
                icon: const Icon(Icons.storefront_outlined),
                label: const Text('Add merchant'),
              ),
            ),
          ],
          body: AppAsyncView(
            isLoading: controller.isLoading,
            errorMessage: controller.errorMessage,
            onRetry: controller.load,
            child: controller.merchants.isEmpty
                ? AppEmptyState(
                    title: 'No merchants yet',
                    message:
                        'Create your first merchant to manage store master data.',
                    action: FilledButton.icon(
                      onPressed: () => Navigator.of(
                        context,
                      ).pushNamed(AppRoutePaths.merchantCreate),
                      icon: const Icon(Icons.add_business_outlined),
                      label: const Text('Create merchant'),
                    ),
                  )
                : ListView.separated(
                    itemCount: controller.merchants.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final merchant = controller.merchants[index];
                      return Card(
                        child: InkWell(
                          borderRadius: BorderRadius.circular(20),
                          onTap: () async {
                            await Navigator.of(
                              context,
                            ).pushNamed('/merchants/${merchant.id.value}');
                            if (context.mounted) {
                              await controller.load();
                            }
                          },
                          child: Padding(
                            padding: const EdgeInsets.all(20),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  merchant.name,
                                  style: Theme.of(context).textTheme.titleLarge,
                                ),
                                const SizedBox(height: 10),
                                Text(merchant.street),
                                Text('${merchant.postCode} ${merchant.city}'),
                                const SizedBox(height: 10),
                                Text(
                                  'Tax ID: ${merchant.taxId}',
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        );
      },
    );
  }
}
