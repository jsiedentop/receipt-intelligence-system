import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http_parser/http_parser.dart';
import 'package:path/path.dart' as path;
import 'package:ris_core/ris_core.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart';
import 'package:shelf_router/shelf_router.dart';

final _router = Router()
  ..get('/healthz', _healthHandler)
  ..post('/v1/extractions', _extractHandler);

Response _healthHandler(Request request) {
  return _jsonResponse(HttpStatus.ok, {'status': 'ok'});
}

Future<Response> _extractHandler(Request request) async {
  try {
    final upload = await _readUpload(request);
    final delayMs = int.tryParse(Platform.environment['RIS_EXTRACT_MOCK_DELAY_MS'] ?? '0') ?? 0;
    if (delayMs > 0) {
      await Future<void>.delayed(Duration(milliseconds: delayMs));
    }
    final fixtureFile = await _resolveFixtureFile(upload.fileName);
    final fixtureJson = jsonDecode(await fixtureFile.readAsString()) as Map<String, dynamic>;
    fixtureJson['requestId'] = upload.requestId.value;
    return Response.ok(
      jsonEncode(fixtureJson),
      headers: {'content-type': 'application/json'},
    );
  } on MockApiException catch (error) {
    return _jsonResponse(error.statusCode, {'error': error.message});
  } catch (_) {
    return _jsonResponse(HttpStatus.internalServerError, {
      'error': 'Internal server error.',
    });
  }
}

Future<_UploadedFile> _readUpload(Request request) async {
  final contentTypeHeader = request.headers[HttpHeaders.contentTypeHeader];
  if (contentTypeHeader == null) {
    throw BadRequestException('Expected multipart/form-data request.');
  }

  final contentType = MediaType.parse(contentTypeHeader);
  if (contentType.type != 'multipart' || contentType.subtype != 'form-data') {
    throw BadRequestException('Expected multipart/form-data request.');
  }

  final boundary = contentType.parameters['boundary'];
  if (boundary == null || boundary.isEmpty) {
    throw BadRequestException('Missing multipart boundary.');
  }

  final bodyBytes = await request.read().expand((chunk) => chunk).toList();
  final body = latin1.decode(bodyBytes);
  final boundaryMarker = '--$boundary';
  if (!body.contains(boundaryMarker)) {
    throw BadRequestException('Malformed multipart body.');
  }

  final match = RegExp(
    'content-disposition:[^\r\n]*name="file"; filename="([^"]+)"',
    caseSensitive: false,
  ).firstMatch(body);
  if (match == null) {
    throw BadRequestException('Missing upload field "file".');
  }

  final fileName = match.group(1);
  if (fileName == null || fileName.isEmpty) {
    throw BadRequestException('Upload field "file" must include a file name.');
  }

  final requestIdMatch = RegExp(
    'content-disposition:[^\r\n]*name="requestId"\r\n\r\n([^\r\n]+)',
    caseSensitive: false,
  ).firstMatch(body);
  if (requestIdMatch == null) {
    throw BadRequestException('Missing upload field "requestId".');
  }

  final requestIdValue = requestIdMatch.group(1)?.trim();
  if (requestIdValue == null || requestIdValue.isEmpty) {
    throw BadRequestException('Upload field "requestId" must not be empty.');
  }

  final requestId = ExtractRequestId(requestIdValue);
  if (!requestId.isValid) {
    throw BadRequestException('Upload field "requestId" must start with "ext_".');
  }

  return _UploadedFile(
    fileName: path.basename(fileName),
    requestId: requestId,
  );
}

Future<File> _resolveFixtureFile(String fileName) async {
  final fixtureName = switch (fileName) {
    'receipt-1.png' => 'recipe-1.json',
    'receipt-2.png' => 'recipe-2.json',
    _ => throw FixtureNotFoundException(
      'No fixture mapping exists for file "$fileName".',
    ),
  };

  final fixturePath = path.normalize(
    path.join(Directory.current.path, '..', '..', 'data', fixtureName),
  );
  final file = File(fixturePath);
  if (!await file.exists()) {
    throw InternalFixtureException(
      'Fixture file "$fixtureName" does not exist.',
    );
  }

  return file;
}

Response _jsonResponse(int statusCode, Map<String, Object?> body) {
  return Response(
    statusCode,
    body: jsonEncode(body),
    headers: {'content-type': 'application/json'},
  );
}

void main(List<String> args) async {
  final ip = InternetAddress.anyIPv4;
  final handler = Pipeline()
      .addMiddleware(logRequests())
      .addHandler(_router.call);
  final port = int.parse(Platform.environment['PORT'] ?? '8080');
  final server = await serve(handler, ip, port);
  print('Server listening on port ${server.port}');
}

class _UploadedFile {
  const _UploadedFile({required this.fileName, required this.requestId});

  final String fileName;
  final ExtractRequestId requestId;
}

sealed class MockApiException implements Exception {
  const MockApiException(this.message, this.statusCode);

  final String message;
  final int statusCode;
}

class BadRequestException extends MockApiException {
  const BadRequestException(String message)
    : super(message, HttpStatus.badRequest);
}

class FixtureNotFoundException extends MockApiException {
  const FixtureNotFoundException(String message)
    : super(message, HttpStatus.notFound);
}

class InternalFixtureException extends MockApiException {
  const InternalFixtureException(String message)
    : super(message, HttpStatus.internalServerError);
}
