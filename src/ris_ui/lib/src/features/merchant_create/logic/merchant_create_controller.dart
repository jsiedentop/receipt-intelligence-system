import 'package:flutter/foundation.dart';
import 'package:ris_core/ris_core.dart';

import '../data/merchant_create_repository.dart';

class MerchantCreateController extends ChangeNotifier {
  MerchantCreateController(this._repository);

  final MerchantCreateRepository _repository;

  bool _isSubmitting = false;
  bool get isSubmitting => _isSubmitting;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  MerchantResponseDto? _createdMerchant;
  MerchantResponseDto? get createdMerchant => _createdMerchant;

  Future<bool> submit({
    required String name,
    required String street,
    required String postCode,
    required String city,
    required String taxId,
  }) async {
    if (_isSubmitting) {
      return false;
    }

    _isSubmitting = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _createdMerchant = await _repository.createMerchant(
        name: name,
        street: street,
        postCode: postCode,
        city: city,
        taxId: taxId,
      );
      return true;
    } catch (error) {
      _errorMessage = _asMessage(error);
      return false;
    } finally {
      _isSubmitting = false;
      notifyListeners();
    }
  }

  String _asMessage(Object error) {
    if (error is BackendClientException) {
      return error.message;
    }

    return 'Failed to create merchant.';
  }
}
