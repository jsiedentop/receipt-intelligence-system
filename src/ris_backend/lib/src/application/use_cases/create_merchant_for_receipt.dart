import 'package:ris_core/ris_core.dart';

import '../../domain/exceptions/app_exceptions.dart';
import '../../domain/models/merchant.dart';
import '../../domain/models/receipt.dart';
import '../../domain/repositories/merchant_repository.dart';
import '../../domain/repositories/receipt_repository.dart';
import 'create_merchant.dart';

class CreateMerchantForReceiptUseCase {
  const CreateMerchantForReceiptUseCase({
    required ReceiptRepository receiptRepository,
    required MerchantRepository merchantRepository,
  }) : _receiptRepository = receiptRepository,
       _merchantRepository = merchantRepository;

  final ReceiptRepository _receiptRepository;
  final MerchantRepository _merchantRepository;

  Future<Receipt> execute({
    required ReceiptId receiptId,
    required CreateMerchantCommand command,
  }) async {
    final receipt = await _receiptRepository.getById(receiptId);
    if (receipt.merchantId != null) {
      throw ReceiptMerchantConflictException(
        'Receipt "${receiptId.value}" already has an assigned merchant.',
      );
    }

    final name = command.name.trim();
    final street = command.street.trim();
    final postCode = command.postCode.trim();
    final city = command.city.trim();
    final taxId = _normalizeNullable(command.taxId);

    if (name.isEmpty) {
      throw ValidationException('Field "name" must not be empty.');
    }
    if (street.isEmpty) {
      throw ValidationException('Field "street" must not be empty.');
    }
    if (postCode.isEmpty) {
      throw ValidationException('Field "postCode" must not be empty.');
    }
    if (city.isEmpty) {
      throw ValidationException('Field "city" must not be empty.');
    }
    final merchant = Merchant(
      id: MerchantId.create(),
      name: name,
      street: street,
      postCode: postCode,
      city: city,
      taxId: taxId,
    );

    await _merchantRepository.create(merchant);
    await _receiptRepository.assignMerchant(
      receiptId: receiptId,
      merchantId: merchant.id,
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
