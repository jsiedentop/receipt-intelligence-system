import 'package:ris_core/ris_core.dart';

abstract interface class ExtractService {
  Future<ExtractResponse> extractReceipt({
    required ExtractRequestId requestId,
    required List<int> bytes,
    required String fileName,
    required String mimeType,
  });
}
