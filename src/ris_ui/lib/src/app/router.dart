import 'package:flutter/material.dart';

import '../features/merchant_create/ui/merchant_create_screen.dart';
import '../features/merchant_detail/ui/merchant_detail_screen.dart';
import '../features/merchants_list/ui/merchants_list_screen.dart';
import '../features/receipt_detail/ui/receipt_detail_screen.dart';
import '../features/receipt_upload/ui/receipt_upload_screen.dart';
import '../features/receipts_list/ui/receipts_list_screen.dart';

abstract final class AppRoutePaths {
  static const receipts = '/';
  static const merchants = '/merchants';
  static const merchantCreate = '/merchants/create';
  static const upload = '/upload';
}

Route<dynamic> generateRoute(RouteSettings settings) {
  final uri = Uri.parse(settings.name ?? AppRoutePaths.receipts);

  if (uri.path == AppRoutePaths.receipts) {
    return MaterialPageRoute<void>(
      builder: (_) => const ReceiptsListScreen(),
      settings: settings,
    );
  }

  if (uri.path == AppRoutePaths.upload) {
    return MaterialPageRoute<void>(
      builder: (_) => const ReceiptUploadScreen(),
      settings: settings,
    );
  }

  if (uri.path == AppRoutePaths.merchants) {
    return MaterialPageRoute<void>(
      builder: (_) => const MerchantsListScreen(),
      settings: settings,
    );
  }

  if (uri.path == AppRoutePaths.merchantCreate) {
    return MaterialPageRoute<void>(
      builder: (_) => const MerchantCreateScreen(),
      settings: settings,
    );
  }

  if (uri.pathSegments.length == 2 && uri.pathSegments.first == 'receipts') {
    return MaterialPageRoute<void>(
      builder: (_) => ReceiptDetailScreen(receiptId: uri.pathSegments[1]),
      settings: settings,
    );
  }

  if (uri.pathSegments.length == 2 && uri.pathSegments.first == 'merchants') {
    return MaterialPageRoute<void>(
      builder: (_) => MerchantDetailScreen(merchantId: uri.pathSegments[1]),
      settings: settings,
    );
  }

  return MaterialPageRoute<void>(
    builder: (_) =>
        const Scaffold(body: Center(child: Text('Page not found.'))),
    settings: settings,
  );
}
