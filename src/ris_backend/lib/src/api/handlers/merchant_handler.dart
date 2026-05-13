import 'dart:convert';
import 'dart:io';

import 'package:ris_core/ris_core.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

import '../../application/use_cases/create_merchant.dart';
import '../../application/use_cases/delete_merchant.dart';
import '../../application/use_cases/get_merchant.dart';
import '../../application/use_cases/list_merchants.dart';
import '../../domain/exceptions/app_exceptions.dart';
import '../errors/http_error_mapper.dart';
import '../mappers/merchant_response_mapper.dart';

class MerchantHandler {
  MerchantHandler({
    required this.createMerchantUseCase,
    required this.deleteMerchantUseCase,
    required this.getMerchantUseCase,
    required this.listMerchantsUseCase,
  });

  final CreateMerchantUseCase createMerchantUseCase;
  final DeleteMerchantUseCase deleteMerchantUseCase;
  final GetMerchantUseCase getMerchantUseCase;
  final ListMerchantsUseCase listMerchantsUseCase;
  final HttpErrorMapper _errorMapper = HttpErrorMapper();
  final MerchantResponseMapper _merchantResponseMapper =
      const MerchantResponseMapper();

  Future<Response> create(Request request) async {
    try {
      final payload = await _parseJsonBody(request);
      final merchant = await createMerchantUseCase.execute(
        CreateMerchantCommand(
          name: _readRequiredString(payload, 'name'),
          street: _readRequiredString(payload, 'street'),
          postCode: _readRequiredString(payload, 'postCode'),
          city: _readRequiredString(payload, 'city'),
          taxId: _readRequiredString(payload, 'taxId'),
        ),
      );
      final responseDto = _merchantResponseMapper.toDto(merchant);

      return Response(
        HttpStatus.created,
        body: jsonEncode(responseDto.toJson()),
        headers: {
          'content-type': 'application/json',
          'location': '/v1/merchants/${merchant.id.value}',
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
      final merchantId = request.params['merchantId'];
      if (merchantId == null || merchantId.isEmpty) {
        throw ValidationException('Missing merchant id.');
      }

      final merchant = await getMerchantUseCase.execute(MerchantId(merchantId));
      final responseDto = _merchantResponseMapper.toDto(merchant);
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

  Future<Response> list(Request request) async {
    try {
      final merchants = await listMerchantsUseCase.execute();
      final responseDtos = merchants
          .map(_merchantResponseMapper.toDto)
          .map((merchant) => merchant.toJson())
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

  Future<Response> delete(Request request) async {
    try {
      final merchantId = request.params['merchantId'];
      if (merchantId == null || merchantId.isEmpty) {
        throw ValidationException('Missing merchant id.');
      }

      await deleteMerchantUseCase.execute(MerchantId(merchantId));
      return Response(HttpStatus.noContent);
    } on AppException catch (error) {
      return _errorMapper.map(error);
    } catch (_) {
      return _errorMapper.internalError();
    }
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
}
