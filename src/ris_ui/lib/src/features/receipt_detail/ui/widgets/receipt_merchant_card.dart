import 'package:flutter/material.dart';
import 'package:ris_core/ris_core.dart';

class ReceiptMerchantCard extends StatefulWidget {
  const ReceiptMerchantCard({
    super.key,
    required this.receipt,
    required this.isSaving,
    required this.onSave,
  });

  final ReceiptResponseDto receipt;
  final bool isSaving;
  final Future<void> Function({
    required String name,
    required String street,
    required String postCode,
    required String city,
    required String taxId,
  })
  onSave;

  @override
  State<ReceiptMerchantCard> createState() => _ReceiptMerchantCardState();
}

class _ReceiptMerchantCardState extends State<ReceiptMerchantCard> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _streetController;
  late final TextEditingController _postCodeController;
  late final TextEditingController _cityController;
  late final TextEditingController _taxIdController;

  @override
  void initState() {
    super.initState();
    final merchantInfo = widget.receipt.extraction?.structured.merchantInfo;
    _nameController = TextEditingController(
      text: merchantInfo?.merchantName ?? '',
    );
    _streetController = TextEditingController(text: merchantInfo?.street ?? '');
    _postCodeController = TextEditingController(
      text: merchantInfo?.postCode ?? '',
    );
    _cityController = TextEditingController(text: merchantInfo?.city ?? '');
    _taxIdController = TextEditingController(text: merchantInfo?.ustid ?? '');
  }

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
    final merchant = widget.receipt.merchant;
    if (merchant != null) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Assigned merchant',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 12),
              _MerchantValue(label: 'Merchant ID', value: merchant.id.value),
              _MerchantValue(label: 'Name', value: merchant.name),
              _MerchantValue(label: 'Street', value: merchant.street),
              _MerchantValue(label: 'Post code', value: merchant.postCode),
              _MerchantValue(label: 'City', value: merchant.city),
              _MerchantValue(label: 'Tax ID', value: merchant.taxId),
            ],
          ),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Create merchant',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Text(
                'Create a merchant from the extracted receipt metadata and link it to this receipt.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Name'),
                validator: _required,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _streetController,
                decoration: const InputDecoration(labelText: 'Street'),
                validator: _required,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _postCodeController,
                decoration: const InputDecoration(labelText: 'Post code'),
                validator: _required,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _cityController,
                decoration: const InputDecoration(labelText: 'City'),
                validator: _required,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _taxIdController,
                decoration: const InputDecoration(labelText: 'Tax ID'),
                validator: _required,
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  FilledButton.icon(
                    onPressed: widget.isSaving
                        ? null
                        : () async {
                            if (!_formKey.currentState!.validate()) {
                              return;
                            }

                            await widget.onSave(
                              name: _nameController.text,
                              street: _streetController.text,
                              postCode: _postCodeController.text,
                              city: _cityController.text,
                              taxId: _taxIdController.text,
                            );
                          },
                    icon: widget.isSaving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.save_outlined),
                    label: Text(widget.isSaving ? 'Saving...' : 'Save'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String? _required(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Required field';
    }

    return null;
  }
}

class _MerchantValue extends StatelessWidget {
  const _MerchantValue({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
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
