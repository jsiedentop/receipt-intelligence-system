import 'package:flutter/material.dart';
import 'package:ris_core/ris_core.dart';

typedef ReceiptItemSaveCallback =
    Future<void> Function({
      required ReceiptItemDto item,
      required String? itemNumber,
      required String? name,
      required double? totalPrice,
      required int? quantity,
      required ReceiptItemCategory? category,
    });

class EditableReceiptItemCard extends StatefulWidget {
  const EditableReceiptItemCard({
    super.key,
    required this.index,
    required this.item,
    required this.currency,
    required this.isSaving,
    required this.onSave,
  });

  final int index;
  final ReceiptItemDto item;
  final String? currency;
  final bool isSaving;
  final ReceiptItemSaveCallback onSave;

  @override
  State<EditableReceiptItemCard> createState() =>
      _EditableReceiptItemCardState();
}

class _EditableReceiptItemCardState extends State<EditableReceiptItemCard> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _itemNumberController;
  late final TextEditingController _nameController;
  late final TextEditingController _totalPriceController;
  late final TextEditingController _quantityController;
  ReceiptItemCategory? _category;

  @override
  void initState() {
    super.initState();
    _itemNumberController = TextEditingController();
    _nameController = TextEditingController();
    _totalPriceController = TextEditingController();
    _quantityController = TextEditingController();
    _syncFromItem();
  }

  @override
  void didUpdateWidget(covariant EditableReceiptItemCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_hasChanged(oldWidget.item, widget.item)) {
      _syncFromItem();
    }
  }

  @override
  void dispose() {
    _itemNumberController.dispose();
    _nameController.dispose();
    _totalPriceController.dispose();
    _quantityController.dispose();
    super.dispose();
  }

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
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        _displayName(),
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                    ),
                    FilledButton.icon(
                      onPressed: widget.isSaving ? null : _save,
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
                const SizedBox(height: 16),
                TextFormField(
                  controller: _itemNumberController,
                  decoration: const InputDecoration(labelText: 'Item number'),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _quantityController,
                  decoration: const InputDecoration(labelText: 'Quantity'),
                  keyboardType: TextInputType.number,
                  validator: _validateQuantity,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(labelText: 'Name'),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _totalPriceController,
                  decoration: const InputDecoration(labelText: 'Total price'),
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  validator: _validateTotalPrice,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<ReceiptItemCategory?>(
                  initialValue: _category,
                  decoration: const InputDecoration(labelText: 'Category'),
                  items: [
                    const DropdownMenuItem<ReceiptItemCategory?>(
                      value: null,
                      child: Text('Unassigned'),
                    ),
                    ...ReceiptItemCategory.values.map(
                      (category) => DropdownMenuItem<ReceiptItemCategory?>(
                        value: category,
                        child: Text(category.apiValue),
                      ),
                    ),
                  ],
                  onChanged: widget.isSaving
                      ? null
                      : (value) {
                          setState(() {
                            _category = value;
                          });
                        },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    await widget.onSave(
      item: widget.item,
      itemNumber: _normalizeNullableText(_itemNumberController.text),
      name: _normalizeNullableText(_nameController.text),
      totalPrice: _parseNullableDouble(_totalPriceController.text),
      quantity: _parseNullableInt(_quantityController.text),
      category: _category,
    );
  }

  void _syncFromItem() {
    _itemNumberController.text = widget.item.itemNumber ?? '';
    _nameController.text = widget.item.name ?? '';
    _totalPriceController.text =
        widget.item.totalPrice?.toStringAsFixed(2) ?? '';
    _quantityController.text = widget.item.quantity?.toString() ?? '';
    _category = widget.item.category;
  }

  bool _hasChanged(ReceiptItemDto previous, ReceiptItemDto next) {
    return previous.id != next.id ||
        previous.itemNumber != next.itemNumber ||
        previous.name != next.name ||
        previous.totalPrice != next.totalPrice ||
        previous.quantity != next.quantity ||
        previous.category != next.category;
  }

  String _displayName() {
    final name = _normalizeNullableText(_nameController.text);
    return name ?? 'Item ${widget.index + 1}';
  }

  String? _validateTotalPrice(String? value) {
    final parsed = _parseNullableDouble(value ?? '');
    if (value != null && value.trim().isNotEmpty && parsed == null) {
      return 'Enter a valid amount';
    }
    if (parsed != null && parsed < 0) {
      return 'Enter an amount of 0 or more';
    }

    return null;
  }

  String? _validateQuantity(String? value) {
    final parsed = _parseNullableInt(value ?? '');
    if (value != null && value.trim().isNotEmpty && parsed == null) {
      return 'Enter a whole number';
    }
    if (parsed != null && parsed < 1) {
      return 'Enter a value of 1 or more';
    }

    return null;
  }
}

String? _normalizeNullableText(String value) {
  final trimmed = value.trim();
  return trimmed.isEmpty ? null : trimmed;
}

double? _parseNullableDouble(String value) {
  final trimmed = value.trim();
  if (trimmed.isEmpty) {
    return null;
  }

  return double.tryParse(trimmed.replaceAll(',', '.'));
}

int? _parseNullableInt(String value) {
  final trimmed = value.trim();
  if (trimmed.isEmpty) {
    return null;
  }

  return int.tryParse(trimmed);
}
