import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:ris_core/ris_core.dart';
import 'package:test/test.dart';

void main() {
  test('parses extract fixture responses', () async {
    final fixtureFile = File('../../data/recipe-1.json');
    final fixtureJson =
        jsonDecode(await fixtureFile.readAsString()) as Map<String, dynamic>;

    final response = ExtractResponse.fromJson(fixtureJson);

    expect(response.requestId.value, 'ext_1a789ec91878');
    expect(response.source.fileName, 'tmp80blzw3o.png');
    expect(response.ocr.blocks, isNotEmpty);
    expect(response.metadata.extractor, 'ris_extract_donut');
  });

  test('extract client parses successful JSON responses', () async {
    final client = ExtractClient(
      config: ExtractClientConfig(baseUri: Uri.parse('http://localhost:8081')),
      httpClient: _FakeHttpClient(),
    );

    final response = await client.extractReceipt(
      requestId: ExtractRequestId('ext_fake'),
      bytes: [1, 2, 3],
      fileName: 'receipt-1.png',
      mimeType: 'image/png',
    );

    expect(response.requestId.value, 'ext_fake');
    expect(response.metadata.extractor, 'ris_extract_mock');
  });

  test('parses backend receipt response dto', () {
    final dto = ReceiptResponseDto.fromJson({
      'id': 'rcp_12345678901234',
      'createdAt': '2026-05-12T20:17:12.345678Z',
      'status': 'processed',
      'extractRequestId': 'ext_12345678901234',
      'image': {
        'originalFileName': 'receipt-1.png',
        'mimeType': 'image/png',
        'storagePath': 'receipts/rcp_12345678901234/original.png',
        'sha256': 'abc',
        'sizeBytes': 123,
      },
      'extraction': {
        'requestId': 'ext_12345678901234',
        'rawText': 'demo',
        'ocr': {'rawText': 'demo', 'blocks': <Object?>[], 'lines': <Object?>[]},
        'metadata': {
          'extractor': 'ris_extract_mock',
          'version': '0.1.0',
          'models': {
            'ocr': {
              'name': 'fixture',
              'textDetectionModel': 'fixture',
              'textRecognitionModel': 'fixture',
              'status': 'ok',
            },
          },
          'runtime': {'python': 'dart', 'platform': 'test'},
        },
        'warnings': <Object?>[],
      },
    });

    expect(dto.id.value, 'rcp_12345678901234');
    expect(dto.extractRequestId.value, 'ext_12345678901234');
    expect(dto.extraction!.requestId.value, 'ext_12345678901234');
  });

  test('backend client parses create receipt responses', () async {
    final client = BackendClient(
      config: BackendClientConfig(baseUri: Uri.parse('http://localhost:8080')),
      httpClient: _FakeBackendHttpClient(),
    );

    final response = await client.createReceipt(
      bytes: [1, 2, 3],
      fileName: 'receipt-1.png',
      mimeType: 'image/png',
    );

    expect(response.id.value, 'rcp_12345678901234');
    expect(response.status, 'pending');
    expect(response.extractRequestId.value, 'ext_12345678901234');
    expect(response.extraction, isNull);
  });

  test('backend client parses get receipt responses', () async {
    final client = BackendClient(
      config: BackendClientConfig(baseUri: Uri.parse('http://localhost:8080')),
      httpClient: _FakeBackendHttpClient(),
    );

    final response = await client.getReceiptById(
      ReceiptId('rcp_12345678901234'),
    );

    expect(response.id.value, 'rcp_12345678901234');
    expect(response.status, 'processed');
    expect(response.extraction, isNotNull);
  });

  test('backend client parses paginated receipt list responses', () async {
    final client = BackendClient(
      config: BackendClientConfig(baseUri: Uri.parse('http://localhost:8080')),
      httpClient: _FakeBackendHttpClient(),
    );

    final response = await client.listReceipts(page: 1, pageSize: 2);

    expect(response, hasLength(2));
    expect(response.first.id.value, 'rcp_99999999999999');
    expect(response.first.status, 'processing');
    expect(response.first.extraction, isNull);
    expect(response.last.id.value, 'rcp_12345678901234');
  });

  test('backend client parses receipt image responses', () async {
    final client = BackendClient(
      config: BackendClientConfig(baseUri: Uri.parse('http://localhost:8080')),
      httpClient: _FakeBackendHttpClient(),
    );

    final response = await client.getReceiptImage(
      ReceiptId('rcp_12345678901234'),
    );

    expect(response.mimeType, 'image/png');
    expect(response.bytes, [1, 2, 3, 4]);
  });

  test('backend client accepts delete receipt responses', () async {
    final client = BackendClient(
      config: BackendClientConfig(baseUri: Uri.parse('http://localhost:8080')),
      httpClient: _FakeBackendHttpClient(),
    );

    await client.deleteReceipt(ReceiptId('rcp_12345678901234'));
  });

  test('backend client parses restart extraction responses', () async {
    final client = BackendClient(
      config: BackendClientConfig(baseUri: Uri.parse('http://localhost:8080')),
      httpClient: _FakeBackendHttpClient(),
    );

    final response = await client.restartReceiptExtraction(
      ReceiptId('rcp_12345678901234'),
    );

    expect(response.status, 'pending');
    expect(response.extractRequestId.value, 'ext_99999999999999');
    expect(response.extraction, isNull);
  });

  test('creates extract request ids', () {
    final id = ExtractRequestId.create();

    expect(id.value, startsWith('ext_'));
    expect(id.isValid, isTrue);
  });
}

class _FakeHttpClient extends http.BaseClient {
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final body = jsonEncode({
      'requestId': 'ext_fake',
      'source': {
        'fileName': 'receipt-1.png',
        'filePath': '/tmp/receipt-1.png',
        'mimeType': 'image/png',
      },
      'warnings': <Object?>[],
      'ocr': {'rawText': 'demo', 'blocks': <Object?>[], 'lines': <Object?>[]},
      'metadata': {
        'extractor': 'ris_extract_mock',
        'version': '0.1.0',
        'models': {
          'ocr': {
            'name': 'fixture',
            'textDetectionModel': 'fixture',
            'textRecognitionModel': 'fixture',
            'status': 'ok',
          },
        },
        'runtime': {'python': 'dart', 'platform': 'test'},
      },
    });

    return http.StreamedResponse(Stream.value(utf8.encode(body)), 200);
  }
}

class _FakeBackendHttpClient extends http.BaseClient {
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    if (request.method == 'DELETE' &&
        request.url.path.endsWith('/v1/receipts/rcp_12345678901234')) {
      return http.StreamedResponse(Stream<List<int>>.empty(), 204);
    }

    if (request.method == 'GET' && request.url.path.endsWith('/image')) {
      return http.StreamedResponse(
        Stream.value([1, 2, 3, 4]),
        200,
        headers: {'content-type': 'image/png'},
      );
    }

    final isRestart = request.method == 'POST' &&
        request.url.path.endsWith('/extractions');
    final isCreate = request.method == 'POST' && !isRestart;
    final isList = request.method == 'GET' &&
        request.url.path.endsWith('/v1/receipts') &&
        request.url.queryParameters.containsKey('page') &&
        request.url.queryParameters.containsKey('pageSize');
    final body = jsonEncode(
      isList
          ? [
              {
                'id': 'rcp_99999999999999',
                'createdAt': '2026-05-13T20:17:12.345678Z',
                'status': 'processing',
                'extractRequestId': 'ext_99999999999999',
                'image': {
                  'originalFileName': 'receipt-2.png',
                  'mimeType': 'image/png',
                  'storagePath': 'receipts/rcp_99999999999999/original.png',
                  'sha256': 'def',
                  'sizeBytes': 456,
                },
                'extraction': null,
              },
              {
                'id': 'rcp_12345678901234',
                'createdAt': '2026-05-12T20:17:12.345678Z',
                'status': 'processed',
                'extractRequestId': 'ext_12345678901234',
                'image': {
                  'originalFileName': 'receipt-1.png',
                  'mimeType': 'image/png',
                  'storagePath': 'receipts/rcp_12345678901234/original.png',
                  'sha256': 'abc',
                  'sizeBytes': 123,
                },
                'extraction': {
                  'requestId': 'ext_12345678901234',
                  'rawText': 'demo',
                  'ocr': {'rawText': 'demo', 'blocks': <Object?>[], 'lines': <Object?>[]},
                  'metadata': {
                    'extractor': 'ris_extract_mock',
                    'version': '0.1.0',
                    'models': {
                      'ocr': {
                        'name': 'fixture',
                        'textDetectionModel': 'fixture',
                        'textRecognitionModel': 'fixture',
                        'status': 'ok',
                      },
                    },
                    'runtime': {'python': 'dart', 'platform': 'test'},
                  },
                  'warnings': <Object?>[],
                },
              },
            ]
          : isCreate || isRestart
              ? {
                  'id': 'rcp_12345678901234',
                  'createdAt': '2026-05-12T20:17:12.345678Z',
                  'status': 'pending',
                  'extractRequestId': isRestart
                      ? 'ext_99999999999999'
                      : 'ext_12345678901234',
                  'image': {
                    'originalFileName': 'receipt-1.png',
                    'mimeType': 'image/png',
                    'storagePath': 'receipts/rcp_12345678901234/original.png',
                    'sha256': 'abc',
                    'sizeBytes': 123,
                  },
                  'extraction': null,
                }
              : {
                  'id': 'rcp_12345678901234',
                  'createdAt': '2026-05-12T20:17:12.345678Z',
                  'status': 'processed',
                  'extractRequestId': 'ext_12345678901234',
                  'image': {
                    'originalFileName': 'receipt-1.png',
                    'mimeType': 'image/png',
                    'storagePath': 'receipts/rcp_12345678901234/original.png',
                    'sha256': 'abc',
                    'sizeBytes': 123,
                  },
                  'extraction': {
                    'requestId': 'ext_12345678901234',
                    'rawText': 'demo',
                    'ocr': {'rawText': 'demo', 'blocks': <Object?>[], 'lines': <Object?>[]},
                    'metadata': {
                      'extractor': 'ris_extract_mock',
                      'version': '0.1.0',
                      'models': {
                        'ocr': {
                          'name': 'fixture',
                          'textDetectionModel': 'fixture',
                          'textRecognitionModel': 'fixture',
                          'status': 'ok',
                        },
                      },
                      'runtime': {'python': 'dart', 'platform': 'test'},
                    },
                    'warnings': <Object?>[],
                  },
                },
    );

    final statusCode = switch (request.method) {
      'POST' => isRestart ? 202 : 201,
      'GET' => 200,
      _ => 500,
    };

    return http.StreamedResponse(Stream.value(utf8.encode(body)), statusCode);
  }
}
