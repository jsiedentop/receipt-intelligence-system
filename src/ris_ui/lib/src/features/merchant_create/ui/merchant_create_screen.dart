import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/widgets/app_shell.dart';
import '../data/merchant_create_repository.dart';
import '../logic/merchant_create_controller.dart';

class MerchantCreateScreen extends StatelessWidget {
  const MerchantCreateScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<MerchantCreateController>(
      create: (context) =>
          MerchantCreateController(context.read<MerchantCreateRepository>()),
      child: const _MerchantCreateView(),
    );
  }
}

class _MerchantCreateView extends StatefulWidget {
  const _MerchantCreateView();

  @override
  State<_MerchantCreateView> createState() => _MerchantCreateViewState();
}

class _MerchantCreateViewState extends State<_MerchantCreateView> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _streetController = TextEditingController();
  final _postCodeController = TextEditingController();
  final _cityController = TextEditingController();
  final _taxIdController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    _streetController.dispose();
    _postCodeController.dispose();
    _cityController.dispose();
    _taxIdController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<MerchantCreateController>(
      builder: (context, controller, child) {
        return AppShell(
          title: 'Create merchant',
          currentSection: AppSection.merchants,
          body: ListView(
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Merchant master data',
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'Create a merchant with the required address and tax identification fields.',
                        ),
                        const SizedBox(height: 24),
                        TextFormField(
                          controller: _nameController,
                          decoration: const InputDecoration(labelText: 'Name'),
                          validator: _required,
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _streetController,
                          decoration: const InputDecoration(
                            labelText: 'Street',
                          ),
                          validator: _required,
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _postCodeController,
                          decoration: const InputDecoration(
                            labelText: 'Post code',
                          ),
                          validator: _required,
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _cityController,
                          decoration: const InputDecoration(labelText: 'City'),
                          validator: _required,
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _taxIdController,
                          decoration: const InputDecoration(
                            labelText: 'Tax ID',
                          ),
                          validator: _required,
                        ),
                        if (controller.errorMessage != null) ...[
                          const SizedBox(height: 18),
                          Text(
                            controller.errorMessage!,
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.error,
                            ),
                          ),
                        ],
                        const SizedBox(height: 24),
                        Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          children: [
                            FilledButton.icon(
                              onPressed: controller.isSubmitting
                                  ? null
                                  : () async {
                                      if (!_formKey.currentState!.validate()) {
                                        return;
                                      }

                                      final success = await controller.submit(
                                        name: _nameController.text,
                                        street: _streetController.text,
                                        postCode: _postCodeController.text,
                                        city: _cityController.text,
                                        taxId: _taxIdController.text,
                                      );
                                      final createdMerchant =
                                          controller.createdMerchant;
                                      if (success &&
                                          createdMerchant != null &&
                                          context.mounted) {
                                        Navigator.of(
                                          context,
                                        ).pushReplacementNamed(
                                          '/merchants/${createdMerchant.id.value}',
                                        );
                                      }
                                    },
                              icon: controller.isSubmitting
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Icon(Icons.save_outlined),
                              label: Text(
                                controller.isSubmitting
                                    ? 'Creating...'
                                    : 'Create merchant',
                              ),
                            ),
                            OutlinedButton(
                              onPressed: controller.isSubmitting
                                  ? null
                                  : () => Navigator.of(context).pop(),
                              child: const Text('Cancel'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  String? _required(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Required field';
    }

    return null;
  }
}
