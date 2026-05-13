import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

import '../ids/extract_request_id.dart';
import 'extract_models.dart';

class ExtractClientConfig {
  const ExtractClientConfig({
    required this.baseUri,
    this.timeout = const Duration(seconds: 30),
  });

  final Uri baseUri;
  final Duration timeout;
}

class ExtractClient {
  ExtractClient({required this.config, http.Client? httpClient})
    : _httpClient = httpClient ?? http.Client(),
      _ownsHttpClient = httpClient == null;

  final ExtractClientConfig config;
  final http.Client _httpClient;
  final bool _ownsHttpClient;

  Future<bool> isHealthy() async {
    final response = await _sendGet('/healthz');
    if (response.statusCode != 200) {
      throw ExtractClientHttpException(
        statusCode: response.statusCode,
        responseBody: response.body,
        message: 'Extract service health check failed.',
      );
    }

    return true;
  }

  Future<ExtractResponse> extractReceipt({
    required ExtractRequestId requestId,
    required List<int> bytes,
    required String fileName,
    String? mimeType,
  }) async {
    if (!requestId.isValid) {
      throw const ExtractClientInvalidRequestException(
        'Extract request id must be non-empty and start with "ext_".',
      );
    }

    final request = http.MultipartRequest(
      'POST',
      config.baseUri.resolve('/v1/extractions'),
    );
    request.fields['requestId'] = requestId.value;

    request.files.add(
      http.MultipartFile.fromBytes(
        'file',
        bytes,
        filename: fileName,
        contentType: mimeType == null ? null : MediaType.parse(mimeType),
      ),
    );

    final response = await _sendMultipart(request);
    if (response.statusCode != 200) {
      throw ExtractClientHttpException(
        statusCode: response.statusCode,
        responseBody: response.body,
        message: 'Extract service returned an unsuccessful response.',
      );
    }

    try {
      final json = _asJsonMap(jsonDecode(response.body), 'extract response');
      final extractResponse = ExtractResponse.fromJson(json);
      if (extractResponse.requestId.value != requestId.value) {
        throw const FormatException(
          'Extract response requestId does not match request.',
        );
      }
      return extractResponse;
    } on FormatException catch (error) {
      throw ExtractClientInvalidResponseException(
        'Extract service returned an invalid JSON payload.',
        cause: error,
      );
    }
  }

  void close() {
    if (_ownsHttpClient) {
      _httpClient.close();
    }
  }

  Future<http.Response> _sendGet(String path) async {
    try {
      return await _httpClient
          .get(config.baseUri.resolve(path))
          .timeout(config.timeout);
    } on TimeoutException catch (error) {
      throw ExtractClientTransportException(
        'Extract service request timed out.',
        cause: error,
      );
    } on http.ClientException catch (error) {
      throw ExtractClientTransportException(
        'Extract service request failed.',
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
      throw ExtractClientTransportException(
        'Extract service request timed out.',
        cause: error,
      );
    } on http.ClientException catch (error) {
      throw ExtractClientTransportException(
        'Extract service request failed.',
        cause: error,
      );
    }
  }
}

class ExtractClientException implements Exception {
  const ExtractClientException(this.message, {this.cause});

  final String message;
  final Object? cause;

  @override
  String toString() => message;
}

class ExtractClientTransportException extends ExtractClientException {
  const ExtractClientTransportException(super.message, {super.cause});
}

class ExtractClientInvalidResponseException extends ExtractClientException {
  const ExtractClientInvalidResponseException(super.message, {super.cause});
}

class ExtractClientInvalidRequestException extends ExtractClientException {
  const ExtractClientInvalidRequestException(super.message, {super.cause});
}

class ExtractClientHttpException extends ExtractClientException {
  const ExtractClientHttpException({
    required this.statusCode,
    required this.responseBody,
    required String message,
  }) : super(message);

  final int statusCode;
  final String responseBody;
}

JsonMap _asJsonMap(Object? value, String fieldName) {
  if (value is JsonMap) {
    return value;
  }

  if (value is Map) {
    return value.map((key, entryValue) => MapEntry(key.toString(), entryValue));
  }

  throw FormatException('Expected $fieldName to be a JSON object.');
}
