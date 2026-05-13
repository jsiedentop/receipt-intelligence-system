import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:ris_core/ris_core.dart';

import '../../../app/router.dart';
import '../../../core/widgets/app_async_view.dart';
import '../../../core/widgets/app_shell.dart';
import '../data/merchant_detail_repository.dart';
import '../logic/merchant_detail_controller.dart';

class MerchantDetailScreen extends StatelessWidget {
  const MerchantDetailScreen({super.key, required this.merchantId});

  final String merchantId;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<MerchantDetailController>(
      create: (context) => MerchantDetailController(
        merchantId: MerchantId(merchantId),
        repository: context.read<MerchantDetailRepository>(),
      )..load(),
      child: const _MerchantDetailView(),
    );
  }
}

class _MerchantDetailView extends StatelessWidget {
  const _MerchantDetailView();

  @override
  Widget build(BuildContext context) {
    return Consumer<MerchantDetailController>(
      builder: (context, controller, child) {
        final merchant = controller.merchant;

        return AppShell(
          title: 'Merchant details',
          currentSection: AppSection.merchants,
          actions: [
            IconButton(
              tooltip: 'Refresh',
              onPressed: controller.load,
              icon: const Icon(Icons.refresh),
            ),
            const SizedBox(width: 8),
          ],
          body: AppAsyncView(
            isLoading: controller.isLoading,
            errorMessage: controller.errorMessage,
            onRetry: controller.load,
            child: merchant == null
                ? const SizedBox.shrink()
                : ListView(
                    children: [
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
                                      merchant.name,
                                      style: Theme.of(
                                        context,
                                      ).textTheme.headlineSmall,
                                    ),
                                  ),
                                  OutlinedButton.icon(
                                    onPressed: controller.isDeleting
                                        ? null
                                        : () async {
                                            final confirmed = await showDialog<bool>(
                                              context: context,
                                              builder: (context) => AlertDialog(
                                                title: const Text(
                                                  'Delete merchant?',
                                                ),
                                                content: const Text(
                                                  'This removes the merchant permanently.',
                                                ),
                                                actions: [
                                                  TextButton(
                                                    onPressed: () =>
                                                        Navigator.of(
                                                          context,
                                                        ).pop(false),
                                                    child: const Text('Cancel'),
                                                  ),
                                                  FilledButton(
                                                    onPressed: () =>
                                                        Navigator.of(
                                                          context,
                                                        ).pop(true),
                                                    child: const Text('Delete'),
                                                  ),
                                                ],
                                              ),
                                            );

                                            if (confirmed == true &&
                                                context.mounted) {
                                              await controller.deleteMerchant();
                                              if (context.mounted) {
                                                Navigator.of(
                                                  context,
                                                ).pushNamedAndRemoveUntil(
                                                  AppRoutePaths.merchants,
                                                  (route) => route.isFirst,
                                                );
                                              }
                                            }
                                          },
                                    icon: const Icon(Icons.delete_outline),
                                    label: Text(
                                      controller.isDeleting
                                          ? 'Deleting...'
                                          : 'Delete',
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 20),
                              _MerchantField(
                                label: 'Merchant ID',
                                value: merchant.id.value,
                              ),
                              _MerchantField(
                                label: 'Street',
                                value: merchant.street,
                              ),
                              _MerchantField(
                                label: 'Post code',
                                value: merchant.postCode,
                              ),
                              _MerchantField(
                                label: 'City',
                                value: merchant.city,
                              ),
                              _MerchantField(
                                label: 'Tax ID',
                                value: merchant.taxId,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
          ),
        );
      },
    );
  }
}

class _MerchantField extends StatelessWidget {
  const _MerchantField({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
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
