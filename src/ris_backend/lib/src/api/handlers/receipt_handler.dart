import 'dart:convert';
import 'dart:io';

import 'package:ris_core/ris_core.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

import '../mappers/receipt_response_mapper.dart';
import '../../application/use_cases/create_merchant.dart';
import '../../application/use_cases/create_receipt.dart';
import '../../application/use_cases/create_merchant_for_receipt.dart';
import '../../application/use_cases/delete_receipt.dart';
import '../../application/use_cases/get_receipt.dart';
import '../../application/use_cases/get_receipt_image.dart';
import '../../application/use_cases/list_receipts.dart';
import '../../application/use_cases/restart_receipt_extraction.dart';
import '../../application/use_cases/update_receipt_item.dart';
import '../../domain/exceptions/app_exceptions.dart';
import '../errors/http_error_mapper.dart';
import '../http/multipart_request_parser.dart';

class ReceiptHandler {
  ReceiptHandler({
    required this.createReceiptUseCase,
    required this.createMerchantForReceiptUseCase,
    required this.deleteReceiptUseCase,
    required this.getReceiptUseCase,
    required this.getReceiptImageUseCase,
    required this.listReceiptsUseCase,
    required this.restartReceiptExtractionUseCase,
    required this.updateReceiptItemUseCase,
  });

  final CreateReceiptUseCase createReceiptUseCase;
  final CreateMerchantForReceiptUseCase createMerchantForReceiptUseCase;
  final DeleteReceiptUseCase deleteReceiptUseCase;
  final GetReceiptUseCase getReceiptUseCase;
  final GetReceiptImageUseCase getReceiptImageUseCase;
  final ListReceiptsUseCase listReceiptsUseCase;
  final RestartReceiptExtractionUseCase restartReceiptExtractionUseCase;
  final UpdateReceiptItemUseCase updateReceiptItemUseCase;
  final HttpErrorMapper _errorMapper = HttpErrorMapper();
  final ReceiptResponseMapper _receiptResponseMapper =
      const ReceiptResponseMapper();

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

  Future<Response> getImage(Request request) async {
    try {
      final receiptId = request.params['receiptId'];
      if (receiptId == null || receiptId.isEmpty) {
        throw ValidationException('Missing receipt id.');
      }

      final receiptImage = await getReceiptImageUseCase.execute(
        ReceiptId(receiptId),
      );
      return Response.ok(
        Stream.value(receiptImage.bytes),
        headers: {'content-type': receiptImage.mimeType},
      );
    } on AppException catch (error) {
      return _errorMapper.map(error);
    } catch (_) {
      return _errorMapper.internalError();
    }
  }

  Future<Response> list(Request request) async {
    try {
      final page = _parsePositiveInt(
        request.url.queryParameters['page'],
        fieldName: 'page',
        fallback: 1,
      );
      final pageSize = _parsePositiveInt(
        request.url.queryParameters['pageSize'],
        fieldName: 'pageSize',
        fallback: 20,
      );
      if (pageSize > 100) {
        throw ValidationException(
          'Query parameter "pageSize" must be at most 100.',
        );
      }

      final receipts = await listReceiptsUseCase.execute(
        page: page,
        pageSize: pageSize,
      );
      final responseDtos = receipts
          .map(_receiptResponseMapper.toDto)
          .map((receipt) => receipt.toJson())
          .toList(growable: false);
      return Response.ok(
        jsonEncode(responseDtos),
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

  Future<Response> createMerchant(Request request) async {
    try {
      final receiptId = request.params['receiptId'];
      if (receiptId == null || receiptId.isEmpty) {
        throw ValidationException('Missing receipt id.');
      }

      final payload = await _parseJsonBody(request);
      final receipt = await createMerchantForReceiptUseCase.execute(
        receiptId: ReceiptId(receiptId),
        command: CreateMerchantCommand(
          name: _readRequiredString(payload, 'name'),
          street: _readRequiredString(payload, 'street'),
          postCode: _readRequiredString(payload, 'postCode'),
          city: _readRequiredString(payload, 'city'),
          taxId: _readNullableString(payload, 'taxId'),
        ),
      );
      final responseDto = _receiptResponseMapper.toDto(receipt);

      return Response(
        HttpStatus.created,
        body: jsonEncode(responseDto.toJson()),
        headers: {'content-type': 'application/json'},
      );
    } on AppException catch (error) {
      return _errorMapper.map(error);
    } catch (_) {
      return _errorMapper.internalError();
    }
  }

  Future<Response> updateItem(Request request) async {
    try {
      final receiptId = request.params['receiptId'];
      final itemId = request.params['itemId'];
      if (receiptId == null || receiptId.isEmpty) {
        throw ValidationException('Missing receipt id.');
      }
      if (itemId == null || itemId.isEmpty) {
        throw ValidationException('Missing item id.');
      }

      final payload = await _parseJsonBody(request);
      final receipt = await updateReceiptItemUseCase.execute(
        receiptId: ReceiptId(receiptId),
        itemId: itemId,
        command: UpdateReceiptItemCommand(
          itemNumber: _readNullableString(payload, 'itemNumber'),
          name: _readNullableString(payload, 'name'),
          totalPrice: _readNullableDouble(payload, 'totalPrice'),
          quantity: _readNullableInt(payload, 'quantity'),
          category: _readNullableCategory(payload, 'category'),
        ),
      );
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

  Future<Response> delete(Request request) async {
    try {
      final receiptId = request.params['receiptId'];
      if (receiptId == null || receiptId.isEmpty) {
        throw ValidationException('Missing receipt id.');
      }

      await deleteReceiptUseCase.execute(ReceiptId(receiptId));
      return Response(HttpStatus.noContent);
    } on AppException catch (error) {
      return _errorMapper.map(error);
    } catch (_) {
      return _errorMapper.internalError();
    }
  }

  int _parsePositiveInt(
    String? value, {
    required String fieldName,
    required int fallback,
  }) {
    if (value == null || value.isEmpty) {
      return fallback;
    }

    final parsed = int.tryParse(value);
    if (parsed == null || parsed < 1) {
      throw ValidationException(
        'Query parameter "$fieldName" must be a positive integer.',
      );
    }

    return parsed;
  }

  Future<Map<String, dynamic>> _parseJsonBody(Request request) async {
    final body = await request.readAsString();
    if (body.trim().isEmpty) {
      throw ValidationException('Request body must not be empty.');
    }

    final decoded = jsonDecode(body);
    if (decoded is Map<String, dynamic>) {
      return decoded;
    }
    if (decoded is Map) {
      return decoded.map((key, value) => MapEntry(key.toString(), value));
    }

    throw ValidationException('Request body must be a JSON object.');
  }

  String _readRequiredString(Map<String, dynamic> payload, String fieldName) {
    final value = payload[fieldName];
    if (value is! String) {
      throw ValidationException('Field "$fieldName" must be a string.');
    }

    return value;
  }

  String? _readNullableString(Map<String, dynamic> payload, String fieldName) {
    final value = payload[fieldName];
    if (value == null) {
      return null;
    }
    if (value is! String) {
      throw ValidationException('Field "$fieldName" must be a string or null.');
    }

    return value;
  }

  double? _readNullableDouble(Map<String, dynamic> payload, String fieldName) {
    final value = payload[fieldName];
    if (value == null) {
      return null;
    }
    if (value is num) {
      return value.toDouble();
    }

    throw ValidationException('Field "$fieldName" must be a number or null.');
  }

  int? _readNullableInt(Map<String, dynamic> payload, String fieldName) {
    final value = payload[fieldName];
    if (value == null) {
      return null;
    }
    if (value is int) {
      return value;
    }

    throw ValidationException('Field "$fieldName" must be an integer or null.');
  }

  ReceiptItemCategory? _readNullableCategory(
    Map<String, dynamic> payload,
    String fieldName,
  ) {
    final value = payload[fieldName];
    if (value == null) {
      return null;
    }
    if (value is! String) {
      throw ValidationException('Field "$fieldName" must be a string or null.');
    }

    try {
      return ReceiptItemCategory.fromApiValue(value);
    } catch (_) {
      throw ValidationException(
        'Field "$fieldName" has an unsupported category value.',
      );
    }
  }
}
