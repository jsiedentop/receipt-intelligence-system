import 'package:flutter/foundation.dart';
import 'package:ris_core/ris_core.dart';

import '../data/receipts_list_repository.dart';

class ReceiptsListController extends ChangeNotifier {
  ReceiptsListController(this._repository);

  final ReceiptsListRepository _repository;

  final List<ReceiptResponseDto> _receipts = <ReceiptResponseDto>[];
  List<ReceiptResponseDto> get receipts => List.unmodifiable(_receipts);

  bool _isInitialLoading = false;
  bool get isInitialLoading => _isInitialLoading;

  bool _isLoadingMore = false;
  bool get isLoadingMore => _isLoadingMore;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  static const int pageSize = 20;
  int _currentPage = 0;
  bool _hasMore = true;
  bool get hasMore => _hasMore;

  Future<void> loadInitial() async {
    if (_isInitialLoading) {
      return;
    }

    _isInitialLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final items = await _repository.listReceipts(page: 1, pageSize: pageSize);
      _receipts
        ..clear()
        ..addAll(items);
      _currentPage = 1;
      _hasMore = items.length == pageSize;
    } catch (error) {
      _errorMessage = _asMessage(error);
    } finally {
      _isInitialLoading = false;
      if (hasListeners) {
        notifyListeners();
      }
    }
  }

  Future<void> refresh() async {
    _currentPage = 0;
    _hasMore = true;
    await loadInitial();
  }

  Future<void> loadMore() async {
    if (_isLoadingMore || !_hasMore || _isInitialLoading) {
      return;
    }

    _isLoadingMore = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final nextPage = _currentPage + 1;
      final items = await _repository.listReceipts(
        page: nextPage,
        pageSize: pageSize,
      );
      _receipts.addAll(items);
      _currentPage = nextPage;
      _hasMore = items.length == pageSize;
    } catch (error) {
      _errorMessage = _asMessage(error);
    } finally {
      _isLoadingMore = false;
      if (hasListeners) {
        notifyListeners();
      }
    }
  }

  String _asMessage(Object error) {
    if (error is BackendClientException) {
      return error.message;
    }

    return 'Failed to load receipts.';
  }
}
