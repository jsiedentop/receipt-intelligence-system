import 'dart:io';

import 'package:ris_core/ris_core.dart';
import 'package:shelf/shelf.dart';

import 'api/handlers/receipt_handler.dart';
import 'api/router.dart';
import 'application/use_cases/create_receipt.dart';
import 'application/use_cases/delete_receipt.dart';
import 'application/use_cases/get_receipt.dart';
import 'application/use_cases/get_receipt_image.dart';
import 'application/use_cases/list_receipts.dart';
import 'application/use_cases/process_receipt_extraction.dart';
import 'application/use_cases/restart_receipt_extraction.dart';
import 'infrastructure/config/backend_config.dart';
import 'infrastructure/db/sqlite_database.dart';
import 'infrastructure/extract/extraction_job_coordinator.dart';
import 'infrastructure/extract/http_extract_service.dart';
import 'infrastructure/repositories/sqlite_receipt_repository.dart';
import 'infrastructure/storage/file_system_image_storage_repository.dart';

Future<Handler> buildHandler(BackendConfig config) async {
  await Directory(config.dataDirectoryPath).create(recursive: true);
  await Directory(config.receiptsImageDirectoryPath).create(recursive: true);

  final sqliteDatabase = SqliteDatabase.open(config.databasePath);
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
  final receiptHandler = ReceiptHandler(
    createReceiptUseCase: createReceiptUseCase,
    deleteReceiptUseCase: deleteReceiptUseCase,
    getReceiptUseCase: getReceiptUseCase,
    getReceiptImageUseCase: getReceiptImageUseCase,
    listReceiptsUseCase: listReceiptsUseCase,
    restartReceiptExtractionUseCase: restartReceiptExtractionUseCase,
  );

  await extractionJobCoordinator.recoverPendingJobs();

  return buildRouter(receiptHandler: receiptHandler);
}
