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
    expect(response.structured.lineItems, isNotNull);
    expect(response.structured.lineItems!.currency, 'EUR');
    expect(response.structured.lineItems!.items, hasLength(2));
    expect(response.metadata.models.llm?.status, 'missing_token');
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
    expect(response.structured.qrcodeTseData, isNull);
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
      'merchantId': 'mer_12345678901234',
      'merchant': {
        'id': 'mer_12345678901234',
        'name': 'Lidl',
        'street': 'Julius-Lossmann-Strasse 11',
        'postCode': '90469',
        'city': 'Nuernberg',
        'taxId': 'DE123456789',
      },
      'merchantAssignedType': 'manual',
      'itemsCurrency': 'EUR',
      'items': [
        {
          'id': 'itm_1',
          'itemNumber': 'SKU-1',
          'name': 'Milk',
          'totalPrice': 1.99,
          'quantity': 2,
          'category': 'FOOD',
        },
      ],
      'validationWarnings': [
        {
          'code': 'ITEM_TOTAL_MISMATCH',
          'message': 'Sum of items differs from extracted total amount.',
        },
      ],
      'extraction': {
        'requestId': 'ext_12345678901234',
        'rawText': 'demo',
        'ocr': {'rawText': 'demo', 'blocks': <Object?>[], 'lines': <Object?>[]},
        'structured': {
          'lineItems': null,
          'merchantInfo': null,
          'qrcode_tse_data': null,
        },
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
            'llm': {
              'provider': 'openai',
              'model': 'gpt-5.4-nano',
              'status': 'missing_token',
            },
          },
          'runtime': {'python': 'dart', 'platform': 'test'},
        },
        'warnings': <Object?>[],
      },
    });

    expect(dto.id.value, 'rcp_12345678901234');
    expect(dto.extractRequestId.value, 'ext_12345678901234');
    expect(dto.merchantId!.value, 'mer_12345678901234');
    expect(dto.merchant!.name, 'Lidl');
    expect(dto.merchantAssignedType, MerchantAssignedTypeDto.manual);
    expect(dto.itemsCurrency, 'EUR');
    expect(dto.items, hasLength(1));
    expect(dto.items.first.category, ReceiptItemCategory.food);
    expect(dto.validationWarnings, hasLength(1));
    expect(dto.extraction!.requestId.value, 'ext_12345678901234');
    expect(dto.extraction!.structured.lineItems, isNull);
  });

  test('parses receipt item category enum from api value', () {
    expect(
      ReceiptItemCategory.fromApiValue('RESTAURANT'),
      ReceiptItemCategory.restaurant,
    );
  });

  test('parses backend merchant response dto', () {
    final dto = MerchantResponseDto.fromJson({
      'id': 'mer_12345678901234',
      'name': 'Lidl',
      'street': 'Julius-Lossmann-Strasse 11',
      'postCode': '90469',
      'city': 'Nuernberg',
      'taxId': 'DE123456789',
      'matchProperties': [
        {
          'id': 1,
          'propertyType': 'merchant_name',
          'propertyValueRaw': 'LDL',
          'propertyValueNormalized': 'ldl',
        },
      ],
    });

    expect(dto.id.value, 'mer_12345678901234');
    expect(dto.name, 'Lidl');
    expect(dto.postCode, '90469');
    expect(dto.city, 'Nuernberg');
    expect(dto.matchProperties, hasLength(1));
  });

  test('parses backend merchant response dto without tax id', () {
    final dto = MerchantResponseDto.fromJson({
      'id': 'mer_12345678901234',
      'name': 'Lidl',
      'street': 'Julius-Lossmann-Strasse 11',
      'postCode': '90469',
      'city': 'Nuernberg',
      'taxId': null,
      'matchProperties': const <Object?>[],
    });

    expect(dto.id.value, 'mer_12345678901234');
    expect(dto.taxId, isNull);
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

  test('backend client parses create merchant responses', () async {
    final client = BackendClient(
      config: BackendClientConfig(baseUri: Uri.parse('http://localhost:8080')),
      httpClient: _FakeBackendHttpClient(),
    );

    final response = await client.createMerchant(
      name: 'Lidl',
      street: 'Julius-Lossmann-Strasse 11',
      postCode: '90469',
      city: 'Nuernberg',
      taxId: 'DE123456789',
    );

    expect(response.id.value, 'mer_12345678901234');
    expect(response.name, 'Lidl');
    expect(response.city, 'Nuernberg');
  });

  test('backend client allows creating merchants without tax id', () async {
    final client = BackendClient(
      config: BackendClientConfig(baseUri: Uri.parse('http://localhost:8080')),
      httpClient: _FakeBackendHttpClient(),
    );

    final response = await client.createMerchant(
      name: 'Lidl',
      street: 'Julius-Lossmann-Strasse 11',
      postCode: '90469',
      city: 'Nuernberg',
      taxId: null,
    );

    expect(response.id.value, 'mer_12345678901234');
    expect(response.taxId, isNull);
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
    expect(response.merchant?.name, 'Lidl');
    expect(response.extraction, isNotNull);
  });

  test('backend client parses create merchant for receipt responses', () async {
    final client = BackendClient(
      config: BackendClientConfig(baseUri: Uri.parse('http://localhost:8080')),
      httpClient: _FakeBackendHttpClient(),
    );

    final response = await client.createMerchantForReceipt(
      receiptId: ReceiptId('rcp_12345678901234'),
      name: 'Lidl',
      street: 'Julius-Lossmann-Strasse 11',
      postCode: '90469',
      city: 'Nuernberg',
      taxId: 'DE123456789',
    );

    expect(response.merchantId?.value, 'mer_12345678901234');
    expect(response.merchant?.city, 'Nuernberg');
    expect(response.merchantAssignedType, MerchantAssignedTypeDto.manual);
  });

  test(
    'backend client allows creating receipt merchant without tax id',
    () async {
      final client = BackendClient(
        config: BackendClientConfig(
          baseUri: Uri.parse('http://localhost:8080'),
        ),
        httpClient: _FakeBackendHttpClient(),
      );

      final response = await client.createMerchantForReceipt(
        receiptId: ReceiptId('rcp_12345678901234'),
        name: 'Lidl',
        street: 'Julius-Lossmann-Strasse 11',
        postCode: '90469',
        city: 'Nuernberg',
        taxId: null,
      );

      expect(response.merchantId?.value, 'mer_12345678901234');
      expect(response.merchant?.taxId, isNull);
    },
  );

  test('backend client parses receipt item update responses', () async {
    final client = BackendClient(
      config: BackendClientConfig(baseUri: Uri.parse('http://localhost:8080')),
      httpClient: _FakeBackendHttpClient(),
    );

    final response = await client.updateReceiptItem(
      receiptId: ReceiptId('rcp_12345678901234'),
      itemId: 'itm_1',
      itemNumber: 'SKU-1',
      name: 'Milk',
      totalPrice: 2.49,
      quantity: 3,
      category: ReceiptItemCategory.food,
    );

    expect(response.items, hasLength(1));
    expect(response.items.first.totalPrice, 2.49);
    expect(response.items.first.quantity, 3);
    expect(response.items.first.category, ReceiptItemCategory.food);
  });

  test('backend client parses merchant candidates', () async {
    final client = BackendClient(
      config: BackendClientConfig(baseUri: Uri.parse('http://localhost:8080')),
      httpClient: _FakeBackendHttpClient(),
    );

    final response = await client.getReceiptMerchantCandidates(
      ReceiptId('rcp_12345678901234'),
    );

    expect(response, hasLength(2));
    expect(response.first.merchantId.value, 'mer_12345678901234');
    expect(response.first.score, closeTo(0.73, 0.0001));
  });

  test('backend client assigns existing merchant to receipt', () async {
    final client = BackendClient(
      config: BackendClientConfig(baseUri: Uri.parse('http://localhost:8080')),
      httpClient: _FakeBackendHttpClient(),
    );

    final response = await client.assignMerchantToReceipt(
      receiptId: ReceiptId('rcp_12345678901234'),
      merchantId: MerchantId('mer_12345678901234'),
    );

    expect(response.merchantId?.value, 'mer_12345678901234');
    expect(response.merchantAssignedType, MerchantAssignedTypeDto.manual);
  });

  test('backend client clears merchant assignment from receipt', () async {
    final client = BackendClient(
      config: BackendClientConfig(baseUri: Uri.parse('http://localhost:8080')),
      httpClient: _FakeBackendHttpClient(),
    );

    final response = await client.clearReceiptMerchant(
      ReceiptId('rcp_12345678901234'),
    );

    expect(response.merchantId, isNull);
    expect(response.merchant, isNull);
    expect(response.merchantAssignedType, MerchantAssignedTypeDto.unmatched);
  });

  test('backend client parses get merchant responses', () async {
    final client = BackendClient(
      config: BackendClientConfig(baseUri: Uri.parse('http://localhost:8080')),
      httpClient: _FakeBackendHttpClient(),
    );

    final response = await client.getMerchantById(
      MerchantId('mer_12345678901234'),
    );

    expect(response.id.value, 'mer_12345678901234');
    expect(response.street, 'Julius-Lossmann-Strasse 11');
    expect(response.city, 'Nuernberg');
    expect(response.matchProperties, isNotEmpty);
  });

  test('backend client deletes merchant match property', () async {
    final client = BackendClient(
      config: BackendClientConfig(baseUri: Uri.parse('http://localhost:8080')),
      httpClient: _FakeBackendHttpClient(),
    );

    final response = await client.deleteMerchantMatchProperty(
      merchantId: MerchantId('mer_12345678901234'),
      propertyId: 1,
    );

    expect(response.matchProperties, hasLength(1));
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

  test('backend client parses merchant list responses', () async {
    final client = BackendClient(
      config: BackendClientConfig(baseUri: Uri.parse('http://localhost:8080')),
      httpClient: _FakeBackendHttpClient(),
    );

    final response = await client.listMerchants();

    expect(response, hasLength(2));
    expect(response.first.id.value, 'mer_99999999999999');
    expect(response.last.name, 'Lidl');
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

  test('backend client accepts delete merchant responses', () async {
    final client = BackendClient(
      config: BackendClientConfig(baseUri: Uri.parse('http://localhost:8080')),
      httpClient: _FakeBackendHttpClient(),
    );

    await client.deleteMerchant(MerchantId('mer_12345678901234'));
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
      'structured': {
        'lineItems': null,
        'merchantInfo': null,
        'qrcode_tse_data': null,
      },
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
          'llm': {
            'provider': 'openai',
            'model': 'gpt-5.4-nano',
            'status': 'missing_token',
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
    final requestedTaxId = _readRequestTaxId(request);

    if (request.method == 'DELETE' &&
        request.url.path.endsWith('/v1/merchants/mer_12345678901234')) {
      return http.StreamedResponse(Stream<List<int>>.empty(), 204);
    }

    if (request.method == 'DELETE' &&
        request.url.path.endsWith(
          '/v1/merchants/mer_12345678901234/match-properties/1',
        )) {
      final body = jsonEncode({
        'id': 'mer_12345678901234',
        'name': 'Lidl',
        'street': 'Julius-Lossmann-Strasse 11',
        'postCode': '90469',
        'city': 'Nuernberg',
        'taxId': 'DE123456789',
        'matchProperties': [
          {
            'id': 2,
            'propertyType': 'street',
            'propertyValueRaw': 'Julius-Loßmann-Straße 11',
            'propertyValueNormalized': 'julius lossmann strasse 11',
          },
        ],
      });
      return http.StreamedResponse(Stream.value(utf8.encode(body)), 200);
    }

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

    final isRestart =
        request.method == 'POST' && request.url.path.endsWith('/extractions');
    final isCreate = request.method == 'POST' && !isRestart;
    final isMerchantCreate =
        request.method == 'POST' && request.url.path.endsWith('/v1/merchants');
    final isCandidateList =
        request.method == 'GET' &&
        request.url.path.endsWith('/merchant-candidates');
    final isList =
        request.method == 'GET' &&
        request.url.path.endsWith('/v1/receipts') &&
        request.url.queryParameters.containsKey('page') &&
        request.url.queryParameters.containsKey('pageSize');
    final isMerchantList =
        request.method == 'GET' && request.url.path.endsWith('/v1/merchants');
    final body = jsonEncode(
      isMerchantList
          ? [
              {
                'id': 'mer_99999999999999',
                'name': 'Aldi',
                'street': 'Marktstrasse 1',
                'postCode': '10115',
                'city': 'Berlin',
                'taxId': 'DE999999999',
                'matchProperties': const <Object?>[],
              },
              {
                'id': 'mer_12345678901234',
                'name': 'Lidl',
                'street': 'Julius-Lossmann-Strasse 11',
                'postCode': '90469',
                'city': 'Nuernberg',
                'taxId': 'DE123456789',
                'matchProperties': [
                  {
                    'id': 1,
                    'propertyType': 'merchant_name',
                    'propertyValueRaw': 'LDL',
                    'propertyValueNormalized': 'ldl',
                  },
                  {
                    'id': 2,
                    'propertyType': 'street',
                    'propertyValueRaw': 'Julius-Loßmann-Straße 11',
                    'propertyValueNormalized': 'julius lossmann strasse 11',
                  },
                ],
              },
            ]
          : isCandidateList
          ? [
              {
                'merchantId': 'mer_12345678901234',
                'score': 0.73,
                'merchant': {
                  'id': 'mer_12345678901234',
                  'name': 'Lidl',
                  'street': 'Julius-Lossmann-Strasse 11',
                  'postCode': '90469',
                  'city': 'Nuernberg',
                  'taxId': 'DE123456789',
                },
              },
              {
                'merchantId': 'mer_99999999999999',
                'score': 0.13,
                'merchant': {
                  'id': 'mer_99999999999999',
                  'name': 'Aldi',
                  'street': 'Marktstrasse 1',
                  'postCode': '10115',
                  'city': 'Berlin',
                  'taxId': 'DE999999999',
                },
              },
            ]
          : isList
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
                'merchantId': null,
                'merchant': null,
                'merchantAssignedType': 'unmatched',
                'itemsCurrency': null,
                'items': const <Object?>[],
                'validationWarnings': const <Object?>[],
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
                'merchantId': 'mer_12345678901234',
                'merchant': {
                  'id': 'mer_12345678901234',
                  'name': 'Lidl',
                  'street': 'Julius-Lossmann-Strasse 11',
                  'postCode': '90469',
                  'city': 'Nuernberg',
                  'taxId': 'DE123456789',
                },
                'merchantAssignedType': 'manual',
                'itemsCurrency': 'EUR',
                'items': [
                  {
                    'id': 'itm_1',
                    'itemNumber': 'SKU-1',
                    'name': 'Milk',
                    'totalPrice': 1.99,
                    'quantity': 2,
                    'category': 'FOOD',
                  },
                ],
                'validationWarnings': const <Object?>[],
                'extraction': {
                  'requestId': 'ext_12345678901234',
                  'rawText': 'demo',
                  'ocr': {
                    'rawText': 'demo',
                    'blocks': <Object?>[],
                    'lines': <Object?>[],
                  },
                  'structured': {
                    'lineItems': null,
                    'merchantInfo': null,
                    'qrcode_tse_data': null,
                  },
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
                      'llm': {
                        'provider': 'openai',
                        'model': 'gpt-5.4-nano',
                        'status': 'missing_token',
                      },
                    },
                    'runtime': {'python': 'dart', 'platform': 'test'},
                  },
                  'warnings': <Object?>[],
                },
              },
            ]
          : isMerchantCreate
          ? {
              'id': 'mer_12345678901234',
              'name': 'Lidl',
              'street': 'Julius-Lossmann-Strasse 11',
              'postCode': '90469',
              'city': 'Nuernberg',
              'taxId': requestedTaxId,
              'matchProperties': const <Object?>[],
            }
          : (isCreate || isRestart) && !request.url.path.endsWith('/merchant')
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
              'merchantId': null,
              'merchant': null,
              'merchantAssignedType': 'unmatched',
              'itemsCurrency': null,
              'items': const <Object?>[],
              'validationWarnings': const <Object?>[],
              'extraction': null,
            }
          : request.method == 'POST' &&
                request.url.path.endsWith(
                  '/v1/receipts/rcp_12345678901234/merchant',
                )
          ? {
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
              'merchantId': 'mer_12345678901234',
              'merchant': {
                'id': 'mer_12345678901234',
                'name': 'Lidl',
                'street': 'Julius-Lossmann-Strasse 11',
                'postCode': '90469',
                'city': 'Nuernberg',
                'taxId': requestedTaxId,
              },
              'merchantAssignedType': 'manual',
              'itemsCurrency': 'EUR',
              'items': [
                {
                  'id': 'itm_1',
                  'itemNumber': 'SKU-1',
                  'name': 'Milk',
                  'totalPrice': 1.99,
                  'quantity': 2,
                  'category': 'FOOD',
                },
              ],
              'validationWarnings': const <Object?>[],
              'extraction': {
                'requestId': 'ext_12345678901234',
                'rawText': 'demo',
                'ocr': {
                  'rawText': 'demo',
                  'blocks': <Object?>[],
                  'lines': <Object?>[],
                },
                'structured': {
                  'lineItems': null,
                  'merchantInfo': null,
                  'qrcode_tse_data': null,
                },
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
                    'llm': {
                      'provider': 'openai',
                      'model': 'gpt-5.4-nano',
                      'status': 'missing_token',
                    },
                  },
                  'runtime': {'python': 'dart', 'platform': 'test'},
                },
                'warnings': <Object?>[],
              },
            }
          : request.method == 'PUT' &&
                request.url.path.endsWith(
                  '/v1/receipts/rcp_12345678901234/merchant',
                )
          ? {
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
              'merchantId': 'mer_12345678901234',
              'merchant': {
                'id': 'mer_12345678901234',
                'name': 'Lidl',
                'street': 'Julius-Lossmann-Strasse 11',
                'postCode': '90469',
                'city': 'Nuernberg',
                'taxId': 'DE123456789',
              },
              'merchantAssignedType': 'manual',
              'itemsCurrency': 'EUR',
              'items': [
                {
                  'id': 'itm_1',
                  'itemNumber': 'SKU-1',
                  'name': 'Milk',
                  'totalPrice': 1.99,
                  'quantity': 2,
                  'category': 'FOOD',
                },
              ],
              'validationWarnings': const <Object?>[],
              'extraction': {
                'requestId': 'ext_12345678901234',
                'rawText': 'demo',
                'ocr': {
                  'rawText': 'demo',
                  'blocks': <Object?>[],
                  'lines': <Object?>[],
                },
                'structured': {
                  'lineItems': null,
                  'merchantInfo': null,
                  'qrcode_tse_data': null,
                },
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
                    'llm': {
                      'provider': 'openai',
                      'model': 'gpt-5.4-nano',
                      'status': 'missing_token',
                    },
                  },
                  'runtime': {'python': 'dart', 'platform': 'test'},
                },
                'warnings': <Object?>[],
              },
            }
          : request.method == 'DELETE' &&
                request.url.path.endsWith(
                  '/v1/receipts/rcp_12345678901234/merchant',
                )
          ? {
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
              'merchantId': null,
              'merchant': null,
              'merchantAssignedType': 'unmatched',
              'itemsCurrency': 'EUR',
              'items': [
                {
                  'id': 'itm_1',
                  'itemNumber': 'SKU-1',
                  'name': 'Milk',
                  'totalPrice': 1.99,
                  'quantity': 2,
                  'category': 'FOOD',
                },
              ],
              'validationWarnings': const <Object?>[],
              'extraction': {
                'requestId': 'ext_12345678901234',
                'rawText': 'demo',
                'ocr': {
                  'rawText': 'demo',
                  'blocks': <Object?>[],
                  'lines': <Object?>[],
                },
                'structured': {
                  'lineItems': null,
                  'merchantInfo': null,
                  'qrcode_tse_data': null,
                },
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
                    'llm': {
                      'provider': 'openai',
                      'model': 'gpt-5.4-nano',
                      'status': 'missing_token',
                    },
                  },
                  'runtime': {'python': 'dart', 'platform': 'test'},
                },
                'warnings': <Object?>[],
              },
            }
          : request.method == 'PATCH' &&
                request.url.path.endsWith(
                  '/v1/receipts/rcp_12345678901234/items/itm_1',
                )
          ? {
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
              'merchantId': 'mer_12345678901234',
              'merchant': {
                'id': 'mer_12345678901234',
                'name': 'Lidl',
                'street': 'Julius-Lossmann-Strasse 11',
                'postCode': '90469',
                'city': 'Nuernberg',
                'taxId': 'DE123456789',
              },
              'merchantAssignedType': 'manual',
              'itemsCurrency': 'EUR',
              'items': [
                {
                  'id': 'itm_1',
                  'itemNumber': 'SKU-1',
                  'name': 'Milk',
                  'totalPrice': 2.49,
                  'quantity': 3,
                  'category': 'FOOD',
                },
              ],
              'validationWarnings': [
                {
                  'code': 'ITEM_TOTAL_MISMATCH',
                  'message':
                      'Sum of items differs from extracted total amount.',
                },
              ],
              'extraction': {
                'requestId': 'ext_12345678901234',
                'rawText': 'demo',
                'ocr': {
                  'rawText': 'demo',
                  'blocks': <Object?>[],
                  'lines': <Object?>[],
                },
                'structured': {
                  'lineItems': null,
                  'merchantInfo': null,
                  'qrcode_tse_data': null,
                },
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
                    'llm': {
                      'provider': 'openai',
                      'model': 'gpt-5.4-nano',
                      'status': 'missing_token',
                    },
                  },
                  'runtime': {'python': 'dart', 'platform': 'test'},
                },
                'warnings': <Object?>[],
              },
            }
          : request.url.path.endsWith('/v1/merchants/mer_12345678901234')
          ? {
              'id': 'mer_12345678901234',
              'name': 'Lidl',
              'street': 'Julius-Lossmann-Strasse 11',
              'postCode': '90469',
              'city': 'Nuernberg',
              'taxId': 'DE123456789',
              'matchProperties': [
                {
                  'id': 1,
                  'propertyType': 'merchant_name',
                  'propertyValueRaw': 'LDL',
                  'propertyValueNormalized': 'ldl',
                },
                {
                  'id': 2,
                  'propertyType': 'street',
                  'propertyValueRaw': 'Julius-Loßmann-Straße 11',
                  'propertyValueNormalized': 'julius lossmann strasse 11',
                },
              ],
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
              'merchantId': 'mer_12345678901234',
              'merchant': {
                'id': 'mer_12345678901234',
                'name': 'Lidl',
                'street': 'Julius-Lossmann-Strasse 11',
                'postCode': '90469',
                'city': 'Nuernberg',
                'taxId': 'DE123456789',
              },
              'merchantAssignedType': 'manual',
              'itemsCurrency': 'EUR',
              'items': [
                {
                  'id': 'itm_1',
                  'itemNumber': 'SKU-1',
                  'name': 'Milk',
                  'totalPrice': 1.99,
                  'quantity': 2,
                  'category': 'FOOD',
                },
              ],
              'validationWarnings': [
                {
                  'code': 'ITEM_TOTAL_MISMATCH',
                  'message':
                      'Sum of items differs from extracted total amount.',
                },
              ],
              'extraction': {
                'requestId': 'ext_12345678901234',
                'rawText': 'demo',
                'ocr': {
                  'rawText': 'demo',
                  'blocks': <Object?>[],
                  'lines': <Object?>[],
                },
                'structured': {
                  'lineItems': null,
                  'merchantInfo': null,
                  'qrcode_tse_data': null,
                },
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
                    'llm': {
                      'provider': 'openai',
                      'model': 'gpt-5.4-nano',
                      'status': 'missing_token',
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
      'PUT' => 200,
      'PATCH' => 200,
      'GET' => 200,
      'DELETE' => request.url.path.endsWith('/merchant') ? 200 : 204,
      _ => 500,
    };

    return http.StreamedResponse(Stream.value(utf8.encode(body)), statusCode);
  }
}

String? _readRequestTaxId(http.BaseRequest request) {
  if (request is! http.Request) {
    return 'DE123456789';
  }

  if (request.body.trim().isEmpty) {
    return 'DE123456789';
  }

  final decoded = jsonDecode(request.body);
  if (decoded is! Map) {
    return 'DE123456789';
  }

  final value = decoded['taxId'];
  return value is String ? value : null;
}
