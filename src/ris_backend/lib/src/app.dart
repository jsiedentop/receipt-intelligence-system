import 'dart:io';

import 'package:ris_core/ris_core.dart';
import 'package:shelf/shelf.dart';

import 'api/handlers/merchant_handler.dart';
import 'api/handlers/receipt_handler.dart';
import 'api/router.dart';
import 'application/use_cases/create_merchant.dart';
import 'application/use_cases/create_merchant_for_receipt.dart';
import 'application/use_cases/create_receipt.dart';
import 'application/use_cases/delete_merchant.dart';
import 'application/use_cases/delete_receipt.dart';
import 'application/use_cases/get_merchant.dart';
import 'application/use_cases/get_receipt.dart';
import 'application/use_cases/get_receipt_image.dart';
import 'application/use_cases/list_merchants.dart';
import 'application/use_cases/list_receipts.dart';
import 'application/use_cases/process_receipt_extraction.dart';
import 'application/use_cases/restart_receipt_extraction.dart';
import 'application/use_cases/update_receipt_item.dart';
import 'infrastructure/config/backend_config.dart';
import 'infrastructure/db/sqlite_database.dart';
import 'infrastructure/extract/extraction_job_coordinator.dart';
import 'infrastructure/extract/http_extract_service.dart';
import 'infrastructure/repositories/sqlite_merchant_repository.dart';
import 'infrastructure/repositories/sqlite_receipt_repository.dart';
import 'infrastructure/storage/file_system_image_storage_repository.dart';

Future<Handler> buildHandler(BackendConfig config) async {
  await Directory(config.dataDirectoryPath).create(recursive: true);
  await Directory(config.receiptsImageDirectoryPath).create(recursive: true);

  final sqliteDatabase = SqliteDatabase.open(config.databasePath);
  final merchantRepository = SqliteMerchantRepository(sqliteDatabase.database);
  final receiptRepository = SqliteReceiptRepository(sqliteDatabase.database);
  final imageStorageRepository = FileSystemImageStorageRepository(
    dataDirectoryPath: config.dataDirectoryPath,
    receiptsImageDirectoryPath: config.receiptsImageDirectoryPath,
  );
  final extractClient = ExtractClient(
    config: ExtractClientConfig(baseUri: config.extractBaseUri),
  );
  final extractService = HttpExtractService(extractClient);
  final processReceiptExtractionUseCase = ProcessReceiptExtractionUseCase(
    receiptRepository: receiptRepository,
    extractService: extractService,
    dataDirectoryPath: config.dataDirectoryPath,
  );
  final extractionJobCoordinator = ExtractionJobCoordinator(
    receiptRepository: receiptRepository,
    processReceiptExtractionUseCase: processReceiptExtractionUseCase,
  );
  final createReceiptUseCase = CreateReceiptUseCase(
    receiptRepository: receiptRepository,
    imageStorageRepository: imageStorageRepository,
    extractionJobDispatcher: extractionJobCoordinator,
  );
  final getReceiptUseCase = GetReceiptUseCase(
    receiptRepository: receiptRepository,
  );
  final getReceiptImageUseCase = GetReceiptImageUseCase(
    receiptRepository: receiptRepository,
    imageStorageRepository: imageStorageRepository,
  );
  final createMerchantUseCase = CreateMerchantUseCase(
    merchantRepository: merchantRepository,
  );
  final createMerchantForReceiptUseCase = CreateMerchantForReceiptUseCase(
    receiptRepository: receiptRepository,
    merchantRepository: merchantRepository,
  );
  final getMerchantUseCase = GetMerchantUseCase(
    merchantRepository: merchantRepository,
  );
  final listMerchantsUseCase = ListMerchantsUseCase(
    merchantRepository: merchantRepository,
  );
  final deleteMerchantUseCase = DeleteMerchantUseCase(
    merchantRepository: merchantRepository,
    receiptRepository: receiptRepository,
  );
  final listReceiptsUseCase = ListReceiptsUseCase(
    receiptRepository: receiptRepository,
  );
  final deleteReceiptUseCase = DeleteReceiptUseCase(
    receiptRepository: receiptRepository,
    imageStorageRepository: imageStorageRepository,
  );
  final restartReceiptExtractionUseCase = RestartReceiptExtractionUseCase(
    receiptRepository: receiptRepository,
    extractionJobDispatcher: extractionJobCoordinator,
  );
  final updateReceiptItemUseCase = UpdateReceiptItemUseCase(
    receiptRepository: receiptRepository,
  );
  final receiptHandler = ReceiptHandler(
    createReceiptUseCase: createReceiptUseCase,
    createMerchantForReceiptUseCase: createMerchantForReceiptUseCase,
    deleteReceiptUseCase: deleteReceiptUseCase,
    getReceiptUseCase: getReceiptUseCase,
    getReceiptImageUseCase: getReceiptImageUseCase,
    listReceiptsUseCase: listReceiptsUseCase,
    restartReceiptExtractionUseCase: restartReceiptExtractionUseCase,
    updateReceiptItemUseCase: updateReceiptItemUseCase,
  );
  final merchantHandler = MerchantHandler(
    createMerchantUseCase: createMerchantUseCase,
    deleteMerchantUseCase: deleteMerchantUseCase,
    getMerchantUseCase: getMerchantUseCase,
    listMerchantsUseCase: listMerchantsUseCase,
  );

  await extractionJobCoordinator.recoverPendingJobs();

  return buildRouter(
    receiptHandler: receiptHandler,
    merchantHandler: merchantHandler,
  );
}
