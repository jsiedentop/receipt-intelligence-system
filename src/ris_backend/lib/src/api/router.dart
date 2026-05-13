import 'dart:convert';
import 'dart:io';

import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

import 'handlers/merchant_handler.dart';
import 'handlers/receipt_handler.dart';

Handler buildRouter({
  required ReceiptHandler receiptHandler,
  required MerchantHandler merchantHandler,
  required String allowedCorsOrigin,
}) {
  final router = Router()
    ..get('/healthz', _healthHandler)
    ..options('/<ignored|.*>', _optionsHandler)
    ..get('/v1/merchants', merchantHandler.list)
    ..post('/v1/merchants', merchantHandler.create)
    ..get('/v1/merchants/<merchantId>', merchantHandler.getById)
    ..delete(
      '/v1/merchants/<merchantId>/match-properties/<propertyId>',
      merchantHandler.deleteMatchProperty,
    )
    ..delete('/v1/merchants/<merchantId>', merchantHandler.delete)
    ..get('/v1/receipts', receiptHandler.list)
    ..post('/v1/receipts', receiptHandler.create)
    ..get(
      '/v1/receipts/<receiptId>/merchant-candidates',
      receiptHandler.listMerchantCandidates,
    )
    ..post('/v1/receipts/<receiptId>/merchant', receiptHandler.createMerchant)
    ..put('/v1/receipts/<receiptId>/merchant', receiptHandler.assignMerchant)
    ..delete(
      '/v1/receipts/<receiptId>/merchant',
      receiptHandler.clearMerchantAssignment,
    )
    ..patch(
      '/v1/receipts/<receiptId>/items/<itemId>',
      receiptHandler.updateItem,
    )
    ..get('/v1/receipts/<receiptId>/image', receiptHandler.getImage)
    ..get('/v1/receipts/<receiptId>', receiptHandler.getById)
    ..post(
      '/v1/receipts/<receiptId>/extractions',
      receiptHandler.restartExtraction,
    )
    ..delete('/v1/receipts/<receiptId>', receiptHandler.delete);

  return Pipeline()
      .addMiddleware(logRequests())
      .addMiddleware(_corsMiddleware(allowedCorsOrigin))
      .addHandler(router.call);
}

Response _healthHandler(Request request) {
  return Response(
    HttpStatus.ok,
    body: jsonEncode({'status': 'ok'}),
    headers: {'content-type': 'application/json'},
  );
}

Response _optionsHandler(Request request) {
  return Response(HttpStatus.noContent);
}

Middleware _corsMiddleware(String allowedCorsOrigin) {
  return (innerHandler) {
    return (request) async {
      final response = await innerHandler(request);
      final origin = request.headers['origin'];
      if (origin != allowedCorsOrigin) {
        return response;
      }

      return response.change(headers: {
        ...response.headers,
        'access-control-allow-origin': allowedCorsOrigin,
        'access-control-allow-methods': 'GET, POST, PUT, PATCH, DELETE, OPTIONS',
        'access-control-allow-headers':
            request.headers['access-control-request-headers'] ??
            'origin, content-type, accept',
        'access-control-allow-credentials': 'true',
        'vary': _appendVaryHeader(response.headers['vary'], 'Origin'),
      });
    };
  };
}

String _appendVaryHeader(String? currentValue, String newValue) {
  if (currentValue == null || currentValue.isEmpty) {
    return newValue;
  }

  final values = currentValue
      .split(',')
      .map((value) => value.trim())
      .where((value) => value.isNotEmpty)
      .toSet();
  values.add(newValue);
  return values.join(', ');
}
