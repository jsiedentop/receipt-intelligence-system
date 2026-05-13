import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/config/backend_config.dart';
import '../core/theme/app_theme.dart';
import '../features/merchant_create/data/merchant_create_repository.dart';
import '../features/merchant_create/data/ris_merchant_create_repository.dart';
import '../features/merchant_detail/data/merchant_detail_repository.dart';
import '../features/merchant_detail/data/ris_merchant_detail_repository.dart';
import '../features/merchants_list/data/merchants_list_repository.dart';
import '../features/merchants_list/data/ris_merchants_list_repository.dart';
import '../features/receipt_detail/data/receipt_detail_repository.dart';
import '../features/receipt_detail/data/ris_receipt_detail_repository.dart';
import '../features/receipt_upload/data/receipt_upload_repository.dart';
import '../features/receipt_upload/data/ris_receipt_upload_repository.dart';
import '../features/receipts_list/data/receipts_list_repository.dart';
import '../features/receipts_list/data/ris_receipts_list_repository.dart';
import 'router.dart';

void bootstrapApp() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const RisApp());
}

class RisApp extends StatelessWidget {
  const RisApp({super.key});

  @override
  Widget build(BuildContext context) {
    final backendClient = buildBackendClient();

    return MultiProvider(
      providers: [
        Provider.value(value: backendClient),
        Provider<MerchantsListRepository>(
          create: (context) => RisMerchantsListRepository(backendClient),
        ),
        Provider<MerchantCreateRepository>(
          create: (context) => RisMerchantCreateRepository(backendClient),
        ),
        Provider<MerchantDetailRepository>(
          create: (context) => RisMerchantDetailRepository(backendClient),
        ),
        Provider<ReceiptsListRepository>(
          create: (context) => RisReceiptsListRepository(backendClient),
        ),
        Provider<ReceiptDetailRepository>(
          create: (context) => RisReceiptDetailRepository(backendClient),
        ),
        Provider<ReceiptUploadRepository>(
          create: (context) => RisReceiptUploadRepository(backendClient),
        ),
      ],
      child: MaterialApp(
        title: 'Receipt Intelligence System',
        debugShowCheckedModeBanner: false,
        theme: buildAppTheme(),
        onGenerateRoute: generateRoute,
        initialRoute: AppRoutePaths.receipts,
      ),
    );
  }
}
