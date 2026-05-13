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
  return buildNamedPageRoute(
    settings.name ?? AppRoutePaths.receipts,
    settings: settings,
  );
}

Route<void> buildNamedPageRoute(
  String routeName, {
  RouteSettings? settings,
  bool animated = true,
}) {
  final resolvedSettings = settings ?? RouteSettings(name: routeName);
  final builder = buildRouteBuilder(routeName);

  return PageRouteBuilder<void>(
    settings: resolvedSettings,
    transitionDuration: animated
        ? const Duration(milliseconds: 220)
        : Duration.zero,
    reverseTransitionDuration: animated
        ? const Duration(milliseconds: 220)
        : Duration.zero,
    pageBuilder: (context, animation, secondaryAnimation) => builder(context),
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      if (!animated) {
        return child;
      }

      final curvedAnimation = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      );

      return FadeTransition(
        opacity: curvedAnimation,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0.02, 0),
            end: Offset.zero,
          ).animate(curvedAnimation),
          child: child,
        ),
      );
    },
  );
}

WidgetBuilder buildRouteBuilder(String routeName) {
  final uri = Uri.parse(routeName);
  late final WidgetBuilder builder;

  if (uri.path == AppRoutePaths.receipts) {
    builder = (_) => const ReceiptsListScreen();
  } else if (uri.path == AppRoutePaths.upload) {
    builder = (_) => const ReceiptUploadScreen();
  } else if (uri.path == AppRoutePaths.merchants) {
    builder = (_) => const MerchantsListScreen();
  } else if (uri.path == AppRoutePaths.merchantCreate) {
    builder = (_) => const MerchantCreateScreen();
  } else if (uri.pathSegments.length == 2 &&
      uri.pathSegments.first == 'receipts') {
    builder = (_) => ReceiptDetailScreen(receiptId: uri.pathSegments[1]);
  } else if (uri.pathSegments.length == 2 &&
      uri.pathSegments.first == 'merchants') {
    builder = (_) => MerchantDetailScreen(merchantId: uri.pathSegments[1]);
  } else {
    builder = (_) => const Scaffold(body: Center(child: Text('Page not found.')));
  }

  return builder;
}
