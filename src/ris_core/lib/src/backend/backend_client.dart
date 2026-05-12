import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

import '../ids/receipt_id.dart';
import 'models/receipt_response_dto.dart';

class BackendClientConfig {
  const BackendClientConfig({
    required this.baseUri,
    this.timeout = const Duration(seconds: 30),
  });

  final Uri baseUri;
  final Duration timeout;
}

class BackendClient {
  BackendClient({required this.config, http.Client? httpClient})
    : _httpClient = httpClient ?? http.Client(),
      _ownsHttpClient = httpClient == null;

  final BackendClientConfig config;
  final http.Client _httpClient;
  final bool _ownsHttpClient;

  Future<bool> isHealthy() async {
    final response = await _sendGet('/healthz');
    if (response.statusCode != 200) {
      throw BackendClientHttpException(
        statusCode: response.statusCode,
        responseBody: response.body,
        message: 'Backend service health check failed.',
      );
    }

    return true;
  }

  Future<ReceiptResponseDto> createReceipt({
    required List<int> bytes,
    required String fileName,
    String? mimeType,
  }) async {
    final request = http.MultipartRequest(
      'POST',
      config.baseUri.resolve('/v1/receipts'),
    );

    request.files.add(
      http.MultipartFile.fromBytes(
        'file',
        bytes,
        filename: fileName,
        contentType: mimeType == null ? null : MediaType.parse(mimeType),
      ),
    );

    final response = await _sendMultipart(request);
    if (response.statusCode != 201) {
      throw BackendClientHttpException(
        statusCode: response.statusCode,
        responseBody: response.body,
        message: 'Backend service returned an unsuccessful create response.',
      );
    }

    return _parseReceiptResponse(response.body);
  }

  Future<ReceiptResponseDto> getReceiptById(ReceiptId receiptId) async {
    final response = await _sendGet('/v1/receipts/${receiptId.value}');
    if (response.statusCode != 200) {
      throw BackendClientHttpException(
        statusCode: response.statusCode,
        responseBody: response.body,
        message: 'Backend service returned an unsuccessful get response.',
      );
    }

    return _parseReceiptResponse(response.body);
  }

  Future<ReceiptResponseDto> restartReceiptExtraction(ReceiptId receiptId) async {
    final response = await _sendPost('/v1/receipts/${receiptId.value}/extractions');
    if (response.statusCode != 202) {
      throw BackendClientHttpException(
        statusCode: response.statusCode,
        responseBody: response.body,
        message: 'Backend service returned an unsuccessful extraction restart response.',
      );
    }

    return _parseReceiptResponse(response.body);
  }

  Future<List<ReceiptResponseDto>> listReceipts({
    int page = 1,
    int pageSize = 20,
  }) async {
    final queryParameters = <String, String>{
      'page': '$page',
      'pageSize': '$pageSize',
    };
    final response = await _sendGetUri(
      config.baseUri.resolve('/v1/receipts').replace(
        queryParameters: queryParameters,
      ),
    );
    if (response.statusCode != 200) {
      throw BackendClientHttpException(
        statusCode: response.statusCode,
        responseBody: response.body,
        message: 'Backend service returned an unsuccessful list response.',
      );
    }

    return _parseReceiptListResponse(response.body);
  }

  Future<void> deleteReceipt(ReceiptId receiptId) async {
    final response = await _sendDelete('/v1/receipts/${receiptId.value}');
    if (response.statusCode != 204) {
      throw BackendClientHttpException(
        statusCode: response.statusCode,
        responseBody: response.body,
        message: 'Backend service returned an unsuccessful delete response.',
      );
    }
  }

  Future<BackendReceiptImage> getReceiptImage(ReceiptId receiptId) async {
    final response = await _sendGet('/v1/receipts/${receiptId.value}/image');
    if (response.statusCode != 200) {
      throw BackendClientHttpException(
        statusCode: response.statusCode,
        responseBody: response.body,
        message: 'Backend service returned an unsuccessful image response.',
      );
    }

    return BackendReceiptImage(
      mimeType: response.headers['content-type'] ?? 'application/octet-stream',
      bytes: response.bodyBytes,
    );
  }

  void close() {
    if (_ownsHttpClient) {
      _httpClient.close();
    }
  }

  Future<http.Response> _sendGet(String path) async {
    return _sendGetUri(config.baseUri.resolve(path));
  }

  Future<http.Response> _sendGetUri(Uri uri) async {
    try {
      return await _httpClient.get(uri).timeout(config.timeout);
    } on TimeoutException catch (error) {
      throw BackendClientTransportException(
        'Backend service request timed out.',
        cause: error,
      );
    } on http.ClientException catch (error) {
      throw BackendClientTransportException(
        'Backend service request failed.',
        cause: error,
      );
    }
  }

  Future<http.Response> _sendMultipart(http.MultipartRequest request) async {
    try {
      final streamedResponse = await _httpClient
          .send(request)
          .timeout(config.timeout);
      return http.Response.fromStream(streamedResponse);
    } on TimeoutException catch (error) {
      throw BackendClientTransportException(
        'Backend service request timed out.',
        cause: error,
      );
    } on http.ClientException catch (error) {
      throw BackendClientTransportException(
        'Backend service request failed.',
        cause: error,
      );
    }
  }

  Future<http.Response> _sendPost(String path) async {
    try {
      return await _httpClient
          .post(config.baseUri.resolve(path))
          .timeout(config.timeout);
    } on TimeoutException catch (error) {
      throw BackendClientTransportException(
        'Backend service request timed out.',
        cause: error,
      );
    } on http.ClientException catch (error) {
      throw BackendClientTransportException(
        'Backend service request failed.',
        cause: error,
      );
    }
  }

  Future<http.Response> _sendDelete(String path) async {
    try {
      return await _httpClient
          .delete(config.baseUri.resolve(path))
          .timeout(config.timeout);
    } on TimeoutException catch (error) {
      throw BackendClientTransportException(
        'Backend service request timed out.',
        cause: error,
      );
    } on http.ClientException catch (error) {
      throw BackendClientTransportException(
        'Backend service request failed.',
        cause: error,
      );
    }
  }

  ReceiptResponseDto _parseReceiptResponse(String source) {
    try {
      final json = _asJsonMap(jsonDecode(source), 'backend receipt response');
      return ReceiptResponseDto.fromJson(json);
    } on FormatException catch (error) {
      throw BackendClientInvalidResponseException(
        'Backend service returned an invalid JSON payload.',
        cause: error,
      );
    }
  }

  List<ReceiptResponseDto> _parseReceiptListResponse(String source) {
    try {
      final decoded = jsonDecode(source);
      if (decoded is! List) {
        throw const FormatException('Expected backend receipt list response to be a JSON array.');
      }

      return decoded
          .map(
            (item) => ReceiptResponseDto.fromJson(
              _asJsonMap(item, 'backend receipt list item'),
            ),
          )
          .toList(growable: false);
    } on FormatException catch (error) {
      throw BackendClientInvalidResponseException(
        'Backend service returned an invalid JSON payload.',
        cause: error,
      );
    }
  }
}

class BackendReceiptImage {
  const BackendReceiptImage({required this.mimeType, required this.bytes});

  final String mimeType;
  final List<int> bytes;
}

class BackendClientException implements Exception {
  const BackendClientException(this.message, {this.cause});

  final String message;
  final Object? cause;

  @override
  String toString() => message;
}

class BackendClientTransportException extends BackendClientException {
  const BackendClientTransportException(super.message, {super.cause});
}

class BackendClientInvalidResponseException extends BackendClientException {
  const BackendClientInvalidResponseException(super.message, {super.cause});
}

class BackendClientHttpException extends BackendClientException {
  const BackendClientHttpException({
    required this.statusCode,
    required this.responseBody,
    required String message,
  }) : super(message);

  final int statusCode;
  final String responseBody;
}

BackendJsonMap _asJsonMap(Object? value, String fieldName) {
  if (value is BackendJsonMap) {
    return value;
  }

  if (value is Map) {
    return value.map(
      (key, entryValue) => MapEntry(key.toString(), entryValue),
    );
  }

  throw FormatException('Expected $fieldName to be a JSON object.');
}
