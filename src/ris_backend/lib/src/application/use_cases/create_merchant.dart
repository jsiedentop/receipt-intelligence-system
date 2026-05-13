import 'package:ris_core/ris_core.dart';

import '../../domain/exceptions/app_exceptions.dart';
import '../../domain/models/merchant.dart';
import '../../domain/repositories/merchant_repository.dart';

class CreateMerchantCommand {
  const CreateMerchantCommand({
    required this.name,
    required this.street,
    required this.postCode,
    required this.city,
    required this.taxId,
  });

  final String name;
  final String street;
  final String postCode;
  final String city;
  final String? taxId;
}

class CreateMerchantUseCase {
  const CreateMerchantUseCase({required MerchantRepository merchantRepository})
    : _merchantRepository = merchantRepository;

  final MerchantRepository _merchantRepository;

  Future<Merchant> execute(CreateMerchantCommand command) async {
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
    return merchant;
  }
}

String? _normalizeNullable(String? value) {
  if (value == null) {
    return null;
  }

  final trimmed = value.trim();
  return trimmed.isEmpty ? null : trimmed;
}
