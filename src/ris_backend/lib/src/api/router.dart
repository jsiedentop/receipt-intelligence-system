import 'dart:convert';
import 'dart:io';

import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

import 'handlers/receipt_handler.dart';

Handler buildRouter({required ReceiptHandler receiptHandler}) {
  final router = Router()
    ..get('/healthz', _healthHandler)
    ..post('/v1/receipts', receiptHandler.create)
    ..get('/v1/receipts/<receiptId>', receiptHandler.getById)
    ..post('/v1/receipts/<receiptId>/extractions', receiptHandler.restartExtraction);

  return Pipeline().addMiddleware(logRequests()).addHandler(router.call);
}

Response _healthHandler(Request request) {
  return Response(
    HttpStatus.ok,
    body: jsonEncode({'status': 'ok'}),
    headers: {'content-type': 'application/json'},
  );
}
