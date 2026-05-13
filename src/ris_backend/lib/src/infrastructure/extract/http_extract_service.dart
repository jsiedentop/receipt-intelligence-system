import 'package:ris_core/ris_core.dart';

import '../../domain/exceptions/app_exceptions.dart';
import '../../domain/services/extract_service.dart';

class HttpExtractService implements ExtractService {
  const HttpExtractService(this._extractClient);

  final ExtractClient _extractClient;

  @override
  Future<ExtractResponse> extractReceipt({
    required ExtractRequestId requestId,
    required List<int> bytes,
    required String fileName,
    required String mimeType,
  }) async {
    try {
      return await _extractClient.extractReceipt(
        requestId: requestId,
        bytes: bytes,
        fileName: fileName,
        mimeType: mimeType,
      );
    } on ExtractClientException catch (error) {
      throw ExtractionFailedException(
        'Failed to extract receipt.',
        cause: error,
      );
    }
  }
}
