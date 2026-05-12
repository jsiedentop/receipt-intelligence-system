import 'dart:convert';
import 'dart:io';

import 'package:http_parser/http_parser.dart';
import 'package:path/path.dart' as path;
import 'package:shelf/shelf.dart';

import '../../domain/exceptions/app_exceptions.dart';

class ParsedMultipartFile {
  const ParsedMultipartFile({
    required this.fieldName,
    required this.fileName,
    required this.bytes,
    this.contentType,
  });

  final String fieldName;
  final String fileName;
  final List<int> bytes;
  final String? contentType;
}

Future<ParsedMultipartFile> parseSingleFileUpload(
  Request request, {
  required String fieldName,
}) async {
  final contentTypeHeader = request.headers[HttpHeaders.contentTypeHeader];
  if (contentTypeHeader == null) {
    throw MalformedMultipartRequestException('Missing Content-Type header.');
  }

  final mediaType = MediaType.parse(contentTypeHeader);
  if (mediaType.type != 'multipart' || mediaType.subtype != 'form-data') {
    throw MalformedMultipartRequestException(
      'Expected multipart/form-data request.',
    );
  }

  final boundary = mediaType.parameters['boundary'];
  if (boundary == null || boundary.isEmpty) {
    throw MalformedMultipartRequestException('Missing multipart boundary.');
  }

  final bodyBytes = await request.read().expand((chunk) => chunk).toList();
  final body = latin1.decode(bodyBytes);
  final boundaryMarker = '--$boundary';
  if (!body.contains(boundaryMarker)) {
    throw MalformedMultipartRequestException('Malformed multipart body.');
  }

  final matches = RegExp(
    'content-disposition:[^\r\n]*name="$fieldName"; filename="([^"]+)"[^\r\n]*\r\n(?:content-type: ([^\r\n]+)\r\n)?\r\n',
    caseSensitive: false,
  ).allMatches(body).toList(growable: false);

  if (matches.isEmpty) {
    throw MissingUploadFileException('Missing upload field "$fieldName".');
  }

  if (matches.length > 1) {
    throw MalformedMultipartRequestException(
      'Expected exactly one file in field "$fieldName".',
    );
  }

  final match = matches.single;
  final fileName = match.group(1);
  if (fileName == null || fileName.isEmpty) {
    throw MissingUploadFileException('Missing uploaded file name.');
  }

  final contentTypeValue = match.group(2)?.trim();
  final contentStart = match.end;
  final contentEnd = body.indexOf('\r\n$boundaryMarker', contentStart);
  if (contentEnd == -1) {
    throw MalformedMultipartRequestException('Malformed multipart body.');
  }

  return ParsedMultipartFile(
    fieldName: fieldName,
    fileName: path.basename(fileName),
    bytes: bodyBytes.sublist(contentStart, contentEnd),
    contentType: contentTypeValue,
  );
}
