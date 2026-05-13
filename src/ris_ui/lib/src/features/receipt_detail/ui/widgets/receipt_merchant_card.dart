import 'package:flutter/material.dart';
import 'package:ris_core/ris_core.dart';

class ReceiptMerchantCard extends StatefulWidget {
  const ReceiptMerchantCard({
    super.key,
    required this.receipt,
    required this.candidates,
    required this.isSaving,
    required this.isLoadingCandidates,
    required this.isClearing,
    required this.onSave,
    required this.onAssignExisting,
    required this.onClearAssignment,
  });

  final ReceiptResponseDto receipt;
  final List<MerchantCandidateDto> candidates;
  final bool isSaving;
  final bool isLoadingCandidates;
  final bool isClearing;
  final Future<void> Function({
    required String name,
    required String street,
    required String postCode,
    required String city,
    required String? taxId,
  }) onSave;
  final Future<void> Function(MerchantId merchantId) onAssignExisting;
  final Future<void> Function() onClearAssignment;

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
    final assignmentLabel = switch (widget.receipt.merchantAssignedType) {
      MerchantAssignedTypeDto.auto => 'Auto assigned',
      MerchantAssignedTypeDto.manual => 'Manually assigned',
      MerchantAssignedTypeDto.unmatched || null => 'Unmatched',
    };

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 12,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  merchant == null ? 'Merchant assignment' : 'Assigned merchant',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    assignmentLabel,
                    style: Theme.of(context).textTheme.labelMedium,
                  ),
                ),
                if (merchant != null)
                  InkWell(
                    onTap: () {
                      Navigator.of(
                        context,
                      ).pushNamed('/merchants/${merchant.id.value}');
                    },
                    child: Text(
                      '#${merchant.id.value}',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: Theme.of(context).colorScheme.primary,
                        decoration: TextDecoration.underline,
                        decorationColor: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            if (merchant != null) ...[
              _MerchantValue(label: 'Name', value: merchant.name),
              _MerchantValue(label: 'Street', value: merchant.street),
              _MerchantValue(label: 'Post code', value: merchant.postCode),
              _MerchantValue(label: 'City', value: merchant.city),
              if (merchant.taxId != null)
                _MerchantValue(label: 'Tax ID', value: merchant.taxId!),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: widget.isClearing
                    ? null
                    : () => widget.onClearAssignment(),
                icon: widget.isClearing
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.link_off_outlined),
                label: Text(
                  widget.isClearing
                      ? 'Removing assignment...'
                      : 'Remove assignment',
                ),
              ),
            ] else ...[
              Text(
                'Choose one of the scored merchant matches or create a new merchant from the extracted receipt metadata.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 16),
              _CandidateSection(
                candidates: widget.candidates,
                isLoading: widget.isLoadingCandidates,
                isSaving: widget.isSaving,
                onAssign: widget.onAssignExisting,
              ),
              const SizedBox(height: 20),
              Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Create new merchant',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    const SizedBox(height: 12),
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
                      decoration: const InputDecoration(
                        labelText: 'Tax ID (optional)',
                      ),
                    ),
                    const SizedBox(height: 16),
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
                      label: Text(widget.isSaving ? 'Saving...' : 'Create merchant'),
                    ),
                  ],
                ),
              ),
            ],
          ],
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

class _CandidateSection extends StatelessWidget {
  const _CandidateSection({
    required this.candidates,
    required this.isLoading,
    required this.isSaving,
    required this.onAssign,
  });

  final List<MerchantCandidateDto> candidates;
  final bool isLoading;
  final bool isSaving;
  final Future<void> Function(MerchantId merchantId) onAssign;

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (candidates.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Text('No merchant candidates available yet.'),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Existing merchants by score',
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: 12),
        ...candidates.map(
          (candidate) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border.all(
                  color: Theme.of(context).colorScheme.outlineVariant,
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          candidate.merchant.name,
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                      ),
                      Text(
                        'Score ${candidate.score.toStringAsFixed(2)}',
                        style: Theme.of(context).textTheme.labelLarge,
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(candidate.merchant.street),
                  Text(
                    '${candidate.merchant.postCode} ${candidate.merchant.city}',
                  ),
                  if (candidate.merchant.taxId != null) ...[
                    const SizedBox(height: 4),
                    Text('Tax ID: ${candidate.merchant.taxId}'),
                  ],
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerRight,
                    child: FilledButton.tonalIcon(
                      onPressed: isSaving
                          ? null
                          : () => onAssign(candidate.merchantId),
                      icon: const Icon(Icons.link_outlined),
                      label: const Text('Assign'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
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
