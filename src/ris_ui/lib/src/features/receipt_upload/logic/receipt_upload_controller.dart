import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:ris_core/ris_core.dart';

import '../data/receipt_upload_repository.dart';

class ReceiptUploadController extends ChangeNotifier {
  ReceiptUploadController(this._repository);

  final ReceiptUploadRepository _repository;

  SelectedReceiptFile? _selectedFile;
  SelectedReceiptFile? get selectedFile => _selectedFile;

  ReceiptResponseDto? _uploadedReceipt;
  ReceiptResponseDto? get uploadedReceipt => _uploadedReceipt;

  bool _isPickingFile = false;
  bool get isPickingFile => _isPickingFile;

  bool _isUploading = false;
  bool get isUploading => _isUploading;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  Timer? _pollTimer;

  Future<void> pickFile() async {
    _isPickingFile = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowMultiple: false,
        withData: true,
        allowedExtensions: const ['png', 'jpg', 'jpeg'],
      );
      final file = result?.files.single;
      if (file == null || file.bytes == null) {
        return;
      }

      final extension = file.extension?.toLowerCase();
      final mimeType = switch (extension) {
        'png' => 'image/png',
        'jpg' || 'jpeg' => 'image/jpeg',
        _ => 'application/octet-stream',
      };

      _selectedFile = SelectedReceiptFile(
        name: file.name,
        bytes: file.bytes!,
        mimeType: mimeType,
      );
    } catch (_) {
      _errorMessage = 'Failed to pick a receipt image.';
    } finally {
      _isPickingFile = false;
      notifyListeners();
    }
  }

  Future<void> upload() async {
    final file = _selectedFile;
    if (file == null) {
      _errorMessage = 'Select a receipt image first.';
      notifyListeners();
      return;
    }

    _isUploading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _uploadedReceipt = await _repository.uploadReceipt(file);
      _configurePolling(_uploadedReceipt!.status);
    } catch (error) {
      _errorMessage = _asMessage(error, fallback: 'Failed to upload receipt.');
    } finally {
      _isUploading = false;
      notifyListeners();
    }
  }

  Future<void> refreshUploadedReceipt() async {
    final receipt = _uploadedReceipt;
    if (receipt == null) {
      return;
    }

    try {
      _uploadedReceipt = await _repository.getReceiptById(receipt.id);
      _configurePolling(_uploadedReceipt!.status);
      notifyListeners();
    } catch (_) {
      _configurePolling('failed');
    }
  }

  void _configurePolling(String status) {
    final shouldPoll = status == 'pending' || status == 'processing';
    _pollTimer?.cancel();
    if (shouldPoll) {
      _pollTimer = Timer.periodic(
        const Duration(seconds: 2),
        (_) => unawaited(refreshUploadedReceipt()),
      );
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
