import 'dart:convert';
import 'dart:io';

import 'package:shelf/shelf.dart';

import '../../domain/exceptions/app_exceptions.dart';

class HttpErrorMapper {
  Response map(AppException error) {
    final statusCode = switch (error) {
      UnsupportedMediaTypeException() => HttpStatus.unsupportedMediaType,
      NotFoundException() => HttpStatus.notFound,
      ConflictException() => HttpStatus.conflict,
      ClientException() => HttpStatus.badRequest,
      ServerException() => HttpStatus.internalServerError,
    };

    return Response(
      statusCode,
      body: jsonEncode({
        'error': {
          'type': error.runtimeType.toString(),
          'message': error.message,
        },
      }),
      headers: {'content-type': 'application/json'},
    );
  }

  Response internalError() {
    return Response(
      HttpStatus.internalServerError,
      body: jsonEncode({
        'error': {
          'type': 'InternalServerError',
          'message': 'Internal server error.',
        },
      }),
      headers: {'content-type': 'application/json'},
    );
  }
}
