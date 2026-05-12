import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:ris_core/ris_core.dart';

import '../data/receipt_detail_repository.dart';

enum OcrOverlayMode { none, lines, blocks }

class ReceiptDetailController extends ChangeNotifier {
  ReceiptDetailController({
    required ReceiptId receiptId,
    required ReceiptDetailRepository repository,
  }) : _receiptId = receiptId,
       _repository = repository;

  final ReceiptId _receiptId;
  final ReceiptDetailRepository _repository;

  ReceiptResponseDto? _receipt;
  ReceiptResponseDto? get receipt => _receipt;

  BackendReceiptImage? _image;
  BackendReceiptImage? get image => _image;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  bool _isRestarting = false;
  bool get isRestarting => _isRestarting;

  bool _isDeleting = false;
  bool get isDeleting => _isDeleting;

  OcrOverlayMode _ocrOverlayMode = OcrOverlayMode.none;
  OcrOverlayMode get ocrOverlayMode => _ocrOverlayMode;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  Timer? _pollTimer;

  bool get hasLineOverlays => _receipt?.extraction?.ocr.lines.isNotEmpty ?? false;

  bool get hasBlockOverlays => _receipt?.extraction?.ocr.blocks.isNotEmpty ?? false;

  bool get hasAnyOverlays => hasLineOverlays || hasBlockOverlays;

  List<OcrElement> get activeOverlayElements {
    final extraction = _receipt?.extraction;
    if (extraction == null) {
      return const <OcrElement>[];
    }

    return switch (_ocrOverlayMode) {
      OcrOverlayMode.none => const <OcrElement>[],
      OcrOverlayMode.lines => extraction.ocr.lines,
      OcrOverlayMode.blocks => extraction.ocr.blocks,
    };
  }

  Future<void> load() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final receipt = await _repository.getReceiptById(_receiptId);
      final image = await _repository.getReceiptImage(_receiptId);
      _receipt = receipt;
      _image = image;
      _syncOverlayMode();
      _configurePolling(receipt.status);
    } catch (error) {
      _errorMessage = _asMessage(error, fallback: 'Failed to load receipt details.');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> refreshSilently() async {
    try {
      final receipt = await _repository.getReceiptById(_receiptId);
      _receipt = receipt;
      _syncOverlayMode();
      _configurePolling(receipt.status);
      notifyListeners();
    } catch (_) {
      _configurePolling('failed');
    }
  }

  Future<void> restartExtraction() async {
    _isRestarting = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _receipt = await _repository.restartReceiptExtraction(_receiptId);
      _syncOverlayMode();
      _configurePolling(_receipt!.status);
    } catch (error) {
      _errorMessage = _asMessage(error, fallback: 'Failed to restart extraction.');
    } finally {
      _isRestarting = false;
      notifyListeners();
    }
  }

  Future<void> deleteReceipt() async {
    _isDeleting = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _repository.deleteReceipt(_receiptId);
      _pollTimer?.cancel();
    } catch (error) {
      _errorMessage = _asMessage(error, fallback: 'Failed to delete receipt.');
      _isDeleting = false;
      notifyListeners();
      rethrow;
    }
  }

  void _configurePolling(String status) {
    final shouldPoll = status == 'pending' || status == 'processing';
    _pollTimer?.cancel();
    if (shouldPoll) {
      _pollTimer = Timer.periodic(
        const Duration(seconds: 2),
        (_) => unawaited(refreshSilently()),
      );
    }
  }

  void setOverlayMode(OcrOverlayMode mode) {
    if (_ocrOverlayMode == mode) {
      return;
    }

    _ocrOverlayMode = mode;
    notifyListeners();
  }

  void _syncOverlayMode() {
    if (_ocrOverlayMode == OcrOverlayMode.lines && !hasLineOverlays) {
      _ocrOverlayMode = OcrOverlayMode.none;
    }
    if (_ocrOverlayMode == OcrOverlayMode.blocks && !hasBlockOverlays) {
      _ocrOverlayMode = OcrOverlayMode.none;
    }
  }

  String _asMessage(Object error, {required String fallback}) {
    if (error is BackendClientException) {
      return error.message;
    }

    return fallback;
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }
}
