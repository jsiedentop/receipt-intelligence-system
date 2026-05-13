import 'package:ris_core/ris_core.dart';

import '../../domain/exceptions/app_exceptions.dart';
import '../../domain/models/receipt.dart';
import '../../domain/repositories/receipt_repository.dart';

class UpdateReceiptItemCommand {
  const UpdateReceiptItemCommand({
    required this.itemNumber,
    required this.name,
    required this.totalPrice,
    required this.quantity,
    required this.category,
  });

  final String? itemNumber;
  final String? name;
  final double? totalPrice;
  final int? quantity;
  final ReceiptItemCategory? category;
}

class UpdateReceiptItemUseCase {
  const UpdateReceiptItemUseCase({required ReceiptRepository receiptRepository})
    : _receiptRepository = receiptRepository;

  final ReceiptRepository _receiptRepository;

  Future<Receipt> execute({
    required ReceiptId receiptId,
    required String itemId,
    required UpdateReceiptItemCommand command,
  }) async {
    if (command.quantity != null && command.quantity! < 1) {
      throw ValidationException(
        'Field "quantity" must be at least 1 when set.',
      );
    }
    if (command.totalPrice != null && command.totalPrice! < 0) {
      throw ValidationException('Field "totalPrice" must not be negative.');
    }

    final existingItem = await _receiptRepository.getItemById(
      receiptId: receiptId,
      itemId: itemId,
    );
    final updatedItem = ReceiptItem(
      id: existingItem.id,
      itemNumber: _normalizeNullable(command.itemNumber),
      name: _normalizeNullable(command.name),
      totalPrice: command.totalPrice,
      quantity: command.quantity,
      category: command.category,
    );
    await _receiptRepository.updateItem(
      receiptId: receiptId,
      item: updatedItem,
    );
    return _receiptRepository.getById(receiptId);
  }
}

String? _normalizeNullable(String? value) {
  if (value == null) {
    return null;
  }

  final trimmed = value.trim();
  return trimmed.isEmpty ? null : trimmed;
}
