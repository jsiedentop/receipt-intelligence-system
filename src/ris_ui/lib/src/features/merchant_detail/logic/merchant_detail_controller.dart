import 'package:flutter/foundation.dart';
import 'package:ris_core/ris_core.dart';

import '../data/merchant_detail_repository.dart';

class MerchantDetailController extends ChangeNotifier {
  MerchantDetailController({
    required MerchantId merchantId,
    required MerchantDetailRepository repository,
  }) : _merchantId = merchantId,
       _repository = repository;

  final MerchantId _merchantId;
  final MerchantDetailRepository _repository;

  MerchantResponseDto? _merchant;
  MerchantResponseDto? get merchant => _merchant;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  bool _isDeleting = false;
  bool get isDeleting => _isDeleting;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  Future<void> load() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _merchant = await _repository.getMerchantById(_merchantId);
    } catch (error) {
      _errorMessage = _asMessage(
        error,
        fallback: 'Failed to load merchant details.',
      );
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> deleteMerchant() async {
    _isDeleting = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _repository.deleteMerchant(_merchantId);
    } catch (error) {
      _errorMessage = _asMessage(error, fallback: 'Failed to delete merchant.');
      _isDeleting = false;
      notifyListeners();
      rethrow;
    }
  }

  String _asMessage(Object error, {required String fallback}) {
    if (error is BackendClientException) {
      return error.message;
    }

    return fallback;
  }
}
