import 'dart:convert';
import 'dart:io';

import 'package:ris_core/ris_core.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

import '../mappers/receipt_response_mapper.dart';
import '../../application/use_cases/create_receipt.dart';
import '../../application/use_cases/get_receipt.dart';
import '../../application/use_cases/restart_receipt_extraction.dart';
import '../../domain/exceptions/app_exceptions.dart';
import '../errors/http_error_mapper.dart';
import '../http/multipart_request_parser.dart';

class ReceiptHandler {
  ReceiptHandler({
    required this.createReceiptUseCase,
    required this.getReceiptUseCase,
    required this.restartReceiptExtractionUseCase,
  });

  final CreateReceiptUseCase createReceiptUseCase;
  final GetReceiptUseCase getReceiptUseCase;
  final RestartReceiptExtractionUseCase restartReceiptExtractionUseCase;
  final HttpErrorMapper _errorMapper = HttpErrorMapper();
  final ReceiptResponseMapper _receiptResponseMapper = const ReceiptResponseMapper();

  Future<Response> create(Request request) async {
    try {
      final upload = await parseSingleFileUpload(request, fieldName: 'file');
      final receipt = await createReceiptUseCase.execute(
        CreateReceiptCommand(
          fileName: upload.fileName,
          mimeType: upload.contentType,
          bytes: upload.bytes,
        ),
      );
      final responseDto = _receiptResponseMapper.toDto(receipt);

      return Response(
        HttpStatus.created,
        body: jsonEncode(responseDto.toJson()),
        headers: {
          'content-type': 'application/json',
          'location': '/v1/receipts/${receipt.id.value}',
        },
      );
    } on AppException catch (error) {
      return _errorMapper.map(error);
    } catch (_) {
      return _errorMapper.internalError();
    }
  }

  Future<Response> getById(Request request) async {
    try {
      final receiptId = request.params['receiptId'];
      if (receiptId == null || receiptId.isEmpty) {
        throw ValidationException('Missing receipt id.');
      }

      final receipt = await getReceiptUseCase.execute(ReceiptId(receiptId));
      final responseDto = _receiptResponseMapper.toDto(receipt);
      return Response.ok(
        jsonEncode(responseDto.toJson()),
        headers: {'content-type': 'application/json'},
      );
    } on AppException catch (error) {
      return _errorMapper.map(error);
    } catch (_) {
      return _errorMapper.internalError();
    }
  }

  Future<Response> restartExtraction(Request request) async {
    try {
      final receiptId = request.params['receiptId'];
      if (receiptId == null || receiptId.isEmpty) {
        throw ValidationException('Missing receipt id.');
      }

      final receipt = await restartReceiptExtractionUseCase.execute(
        ReceiptId(receiptId),
      );
      final responseDto = _receiptResponseMapper.toDto(receipt);
      return Response(
        HttpStatus.accepted,
        body: jsonEncode(responseDto.toJson()),
        headers: {'content-type': 'application/json'},
      );
    } on AppException catch (error) {
      return _errorMapper.map(error);
    } catch (_) {
      return _errorMapper.internalError();
    }
  }
}
