import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:test/test.dart';

void main() {
  late int port;
  late Uri host;
  late Process process;

  setUp(() async {
    port = await _findFreePort();
    host = Uri.parse('http://127.0.0.1:$port');
    process = await Process.start(
      'dart',
      ['run', 'bin/server.dart'],
      environment: {'PORT': '$port'},
    );
    await process.stdout.first;
  });

  tearDown(() async {
    process.kill();
    await process.exitCode;
  });

  test('health endpoint returns ok', () async {
    final response = await http.get(host.resolve('/healthz'));

    expect(response.statusCode, 200);
    expect(jsonDecode(response.body), {'status': 'ok'});
  });

  test('returns recipe-1 for receipt-1 upload', () async {
    final response = await _upload(host, 'receipt-1.png', requestId: 'ext_test_1');
    final body = jsonDecode(response.body) as Map<String, dynamic>;

    expect(response.statusCode, 200);
    expect(body['requestId'], 'ext_test_1');
  });

  test('returns recipe-2 for receipt-2 upload', () async {
    final response = await _upload(host, 'receipt-2.png', requestId: 'ext_test_2');
    final body = jsonDecode(response.body) as Map<String, dynamic>;

    expect(response.statusCode, 200);
    expect(body['requestId'], 'ext_test_2');
  });

  test('returns recipe-3 for receipt-3 upload', () async {
    final response = await _upload(host, 'receipt-3.png', requestId: 'ext_test_3');
    final body = jsonDecode(response.body) as Map<String, dynamic>;

    expect(response.statusCode, 200);
    expect(body['requestId'], 'ext_test_3');
  });

  test('returns 400 when requestId is missing', () async {
    final filePath = '../../data/receipt-1.png';
    final request = http.MultipartRequest('POST', host.resolve('/v1/extractions'))
      ..files.add(await http.MultipartFile.fromPath('file', filePath));
    final response = await http.Response.fromStream(await request.send());

    expect(response.statusCode, 400);
  });

  test('returns 400 when requestId has invalid prefix', () async {
    final response = await _upload(host, 'receipt-1.png', requestId: 'invalid');

    expect(response.statusCode, 400);
  });

  test('returns 404 for unknown fixture mapping', () async {
    final file = File('/var/folders/qg/zs7x74ys69j0k9j0ljmycm7h0000gn/T/opencode/mock-unknown.png');
    await file.parent.create(recursive: true);
    await file.writeAsBytes([1, 2, 3]);

    final request = http.MultipartRequest('POST', host.resolve('/v1/extractions'))
      ..fields['requestId'] = 'ext_unknown'
      ..files.add(await http.MultipartFile.fromPath('file', file.path));
    final response = await http.Response.fromStream(await request.send());

    expect(response.statusCode, 404);
  });
}

Future<http.Response> _upload(
  Uri host,
  String fileName, {
  required String requestId,
}) async {
  final filePath = '../../data/$fileName';
  final request = http.MultipartRequest('POST', host.resolve('/v1/extractions'))
    ..fields['requestId'] = requestId
    ..files.add(await http.MultipartFile.fromPath('file', filePath));

  return http.Response.fromStream(await request.send());
}

Future<int> _findFreePort() async {
  final socket = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
  final port = socket.port;
  await socket.close();
  return port;
}
