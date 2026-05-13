import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:path/path.dart' as path;
import 'package:test/test.dart';

void main() {
  late int backendPort;
  late int extractPort;
  late Uri backendBaseUri;
  late Process backendProcess;
  late Process extractProcess;
  late Directory tempDirectory;

  setUp(() async {
    tempDirectory = await Directory.systemTemp.createTemp('ris_backend_test_');
    extractPort = await _findFreePort();
    backendPort = await _findFreePort();
    backendBaseUri = Uri.parse('http://127.0.0.1:$backendPort');

    extractProcess = await Process.start(
      'dart',
      ['run', 'bin/server.dart'],
      workingDirectory: Directory.current.uri.resolve('../ris_extract_mock/').toFilePath(),
      environment: {
        'PORT': '$extractPort',
        'RIS_EXTRACT_MOCK_DELAY_MS': '1200',
      },
    );
    await extractProcess.stdout.first;

    backendProcess = await Process.start(
      'dart',
      ['run', 'bin/server.dart'],
      environment: {
        'PORT': '$backendPort',
        'RIS_BACKEND_DATA_DIR': tempDirectory.path,
        'RIS_EXTRACT_BASE_URL': 'http://127.0.0.1:$extractPort',
      },
    );
    await backendProcess.stdout.first;
  });

  tearDown(() async {
    backendProcess.kill();
    extractProcess.kill();
    await backendProcess.exitCode;
    await extractProcess.exitCode;
    if (await tempDirectory.exists()) {
      await tempDirectory.delete(recursive: true);
    }
  });

  test('health endpoint returns ok', () async {
    final response = await http.get(backendBaseUri.resolve('/healthz'));

    expect(response.statusCode, 200);
    expect(jsonDecode(response.body), {'status': 'ok'});
  });

  test('creates receipt immediately and exposes processed extraction through polling', () async {
    final startedAt = DateTime.now();
    final createResponse = await _uploadFile(
      backendBaseUri.resolve('/v1/receipts'),
      '../../data/receipt-1.png',
      contentType: MediaType('image', 'png'),
    );
    final elapsed = DateTime.now().difference(startedAt);
    final createdBody = jsonDecode(createResponse.body) as Map<String, dynamic>;
    final receiptId = createdBody['id'] as String;

    expect(createResponse.statusCode, 201);
    expect(elapsed, lessThan(const Duration(milliseconds: 1000)));
    expect(createdBody['status'], 'pending');
    expect(createdBody['extractRequestId'], startsWith('ext_'));
    expect(createdBody['extraction'], isNull);

    final storagePath = createdBody['image']['storagePath'] as String;
    final storedImage = File(path.join(tempDirectory.path, storagePath));
    expect(await storedImage.exists(), isTrue);

    final fetchedBody = await _pollReceipt(
      backendBaseUri,
      receiptId,
      matcher: (body) => body['status'] == 'processed',
    );

    expect(fetchedBody['id'], receiptId);
    expect(fetchedBody['extraction']['rawText'], contains('LDL'));
    expect(
      fetchedBody['extraction']['requestId'],
      createdBody['extractRequestId'],
    );
    expect(fetchedBody['extraction']['structured'], isA<Map<String, dynamic>>());
  });

  test('restart clears stale extraction payload and returns pending receipt', () async {
    final createResponse = await _uploadFile(
      backendBaseUri.resolve('/v1/receipts'),
      '../../data/receipt-1.png',
      contentType: MediaType('image', 'png'),
    );
    final createdBody = jsonDecode(createResponse.body) as Map<String, dynamic>;
    final receiptId = createdBody['id'] as String;

    final processedBody = await _pollReceipt(
      backendBaseUri,
      receiptId,
      matcher: (body) => body['status'] == 'processed',
    );
    final firstRequestId = processedBody['extractRequestId'] as String;

    final restartResponse = await http.post(
      backendBaseUri.resolve('/v1/receipts/$receiptId/extractions'),
    );
    final restartedBody = jsonDecode(restartResponse.body) as Map<String, dynamic>;

    expect(restartResponse.statusCode, 202);
    expect(restartedBody['status'], 'pending');
    expect(restartedBody['extraction'], isNull);
    expect(restartedBody['extractRequestId'], startsWith('ext_'));
    expect(restartedBody['extractRequestId'], isNot(firstRequestId));

    final repolledBody = await _pollReceipt(
      backendBaseUri,
      receiptId,
      matcher: (body) => body['status'] == 'processed',
    );
    expect(repolledBody['extractRequestId'], restartedBody['extractRequestId']);
    expect(repolledBody['extraction'], isNotNull);
  });

  test('returns 409 when restart is requested during active extraction', () async {
    final createResponse = await _uploadFile(
      backendBaseUri.resolve('/v1/receipts'),
      '../../data/receipt-1.png',
      contentType: MediaType('image', 'png'),
    );
    final createdBody = jsonDecode(createResponse.body) as Map<String, dynamic>;
    final receiptId = createdBody['id'] as String;

    final restartResponse = await http.post(
      backendBaseUri.resolve('/v1/receipts/$receiptId/extractions'),
    );

    expect(restartResponse.statusCode, 409);
  });

  test('lists receipts with page and pageSize pagination', () async {
    await _uploadFile(
      backendBaseUri.resolve('/v1/receipts'),
      '../../data/receipt-1.png',
      contentType: MediaType('image', 'png'),
    );
    await Future<void>.delayed(const Duration(milliseconds: 50));
    await _uploadFile(
      backendBaseUri.resolve('/v1/receipts'),
      '../../data/receipt-2.png',
      contentType: MediaType('image', 'png'),
    );
    await Future<void>.delayed(const Duration(milliseconds: 50));
    await _uploadFile(
      backendBaseUri.resolve('/v1/receipts'),
      '../../data/receipt-1.png',
      contentType: MediaType('image', 'png'),
    );

    final pageOneResponse = await http.get(
      backendBaseUri.resolve('/v1/receipts?page=1&pageSize=2'),
    );
    final pageOneBody = jsonDecode(pageOneResponse.body) as List<dynamic>;
    final pageTwoResponse = await http.get(
      backendBaseUri.resolve('/v1/receipts?page=2&pageSize=2'),
    );
    final pageTwoBody = jsonDecode(pageTwoResponse.body) as List<dynamic>;
    final pageThreeResponse = await http.get(
      backendBaseUri.resolve('/v1/receipts?page=3&pageSize=2'),
    );
    final pageThreeBody = jsonDecode(pageThreeResponse.body) as List<dynamic>;

    expect(pageOneResponse.statusCode, 200);
    expect(pageOneBody, hasLength(2));
    expect(pageTwoResponse.statusCode, 200);
    expect(pageTwoBody, hasLength(1));
    expect(pageThreeResponse.statusCode, 200);
    expect(pageThreeBody, isEmpty);

    final firstCreatedAt = DateTime.parse(
      (pageOneBody[0] as Map<String, dynamic>)['createdAt'] as String,
    );
    final secondCreatedAt = DateTime.parse(
      (pageOneBody[1] as Map<String, dynamic>)['createdAt'] as String,
    );
    expect(firstCreatedAt.isAfter(secondCreatedAt), isTrue);
  });

  test('returns 400 for invalid receipt list pagination parameters', () async {
    final zeroPageResponse = await http.get(
      backendBaseUri.resolve('/v1/receipts?page=0&pageSize=20'),
    );
    final oversizedPageResponse = await http.get(
      backendBaseUri.resolve('/v1/receipts?page=1&pageSize=101'),
    );

    expect(zeroPageResponse.statusCode, 400);
    expect(oversizedPageResponse.statusCode, 400);
  });

  test('returns original image bytes for a stored receipt', () async {
    final createResponse = await _uploadFile(
      backendBaseUri.resolve('/v1/receipts'),
      '../../data/receipt-1.png',
      contentType: MediaType('image', 'png'),
    );
    final createdBody = jsonDecode(createResponse.body) as Map<String, dynamic>;
    final receiptId = createdBody['id'] as String;

    final imageResponse = await http.get(
      backendBaseUri.resolve('/v1/receipts/$receiptId/image'),
    );

    expect(imageResponse.statusCode, 200);
    expect(imageResponse.headers['content-type'], startsWith('image/png'));
    expect(imageResponse.bodyBytes, isNotEmpty);
  });

  test('deletes a receipt and removes it from api responses', () async {
    final createResponse = await _uploadFile(
      backendBaseUri.resolve('/v1/receipts'),
      '../../data/receipt-1.png',
      contentType: MediaType('image', 'png'),
    );
    final createdBody = jsonDecode(createResponse.body) as Map<String, dynamic>;
    final receiptId = createdBody['id'] as String;
    final storagePath = createdBody['image']['storagePath'] as String;
    final storedImage = File(path.join(tempDirectory.path, storagePath));

    final deleteResponse = await http.delete(
      backendBaseUri.resolve('/v1/receipts/$receiptId'),
    );
    final getResponse = await http.get(
      backendBaseUri.resolve('/v1/receipts/$receiptId'),
    );
    final imageResponse = await http.get(
      backendBaseUri.resolve('/v1/receipts/$receiptId/image'),
    );
    final listResponse = await http.get(
      backendBaseUri.resolve('/v1/receipts?page=1&pageSize=20'),
    );
    final listedReceipts = jsonDecode(listResponse.body) as List<dynamic>;

    expect(deleteResponse.statusCode, 204);
    expect(getResponse.statusCode, 404);
    expect(imageResponse.statusCode, 404);
    expect(await storedImage.exists(), isFalse);
    expect(
      listedReceipts.where(
        (entry) => (entry as Map<String, dynamic>)['id'] == receiptId,
      ),
      isEmpty,
    );
  });

  test('allows deleting a receipt while extraction is still active', () async {
    final createResponse = await _uploadFile(
      backendBaseUri.resolve('/v1/receipts'),
      '../../data/receipt-1.png',
      contentType: MediaType('image', 'png'),
    );
    final createdBody = jsonDecode(createResponse.body) as Map<String, dynamic>;
    final receiptId = createdBody['id'] as String;

    final deleteResponse = await http.delete(
      backendBaseUri.resolve('/v1/receipts/$receiptId'),
    );

    expect(deleteResponse.statusCode, 204);

    await Future<void>.delayed(const Duration(milliseconds: 1500));

    final getResponse = await http.get(
      backendBaseUri.resolve('/v1/receipts/$receiptId'),
    );
    expect(getResponse.statusCode, 404);
  });

  test('returns 415 for unsupported file types', () async {
    final invalidFile = File(path.join(tempDirectory.path, 'invalid.txt'));
    await invalidFile.writeAsString('not an image');

    final response = await _uploadFile(
      backendBaseUri.resolve('/v1/receipts'),
      invalidFile.path,
      contentType: MediaType('text', 'plain'),
    );

    expect(response.statusCode, 415);
  });

  test('returns 404 for missing receipts', () async {
    final response = await http.get(
      backendBaseUri.resolve('/v1/receipts/missing-id'),
    );

    expect(response.statusCode, 404);
  });
}

Future<Map<String, dynamic>> _pollReceipt(
  Uri backendBaseUri,
  String receiptId, {
  required bool Function(Map<String, dynamic> body) matcher,
}) async {
  final deadline = DateTime.now().add(const Duration(seconds: 10));
  while (DateTime.now().isBefore(deadline)) {
    final response = await http.get(
      backendBaseUri.resolve('/v1/receipts/$receiptId'),
    );
    if (response.statusCode == 200) {
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      if (matcher(body)) {
        return body;
      }
    }
    await Future<void>.delayed(const Duration(milliseconds: 50));
  }

  throw StateError('Polling timed out.');
}

Future<int> _findFreePort() async {
  final socket = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
  final port = socket.port;
  await socket.close();
  return port;
}

Future<http.Response> _uploadFile(
  Uri uri,
  String filePath, {
  required MediaType contentType,
}) async {
  final request = http.MultipartRequest('POST', uri)
    ..files.add(
      await http.MultipartFile.fromPath(
        'file',
        filePath,
        contentType: contentType,
      ),
    );

  return http.Response.fromStream(await request.send());
}
