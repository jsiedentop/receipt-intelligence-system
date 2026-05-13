import 'package:flutter/foundation.dart';
import 'package:ris_core/ris_core.dart';

import '../data/merchants_list_repository.dart';

class MerchantsListController extends ChangeNotifier {
  MerchantsListController(this._repository);

  final MerchantsListRepository _repository;

  final List<MerchantResponseDto> _merchants = <MerchantResponseDto>[];
  List<MerchantResponseDto> get merchants => List.unmodifiable(_merchants);

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  Future<void> load() async {
    if (_isLoading) {
      return;
    }

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final items = await _repository.listMerchants();
      _merchants
        ..clear()
        ..addAll(items);
    } catch (error) {
      _errorMessage = _asMessage(error);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  String _asMessage(Object error) {
    if (error is BackendClientException) {
      return error.message;
    }

    return 'Failed to load merchants.';
  }
}
