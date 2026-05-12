import 'package:path/path.dart' as path;

import '../../domain/exceptions/app_exceptions.dart';

class BackendConfig {
  const BackendConfig({
    required this.port,
    required this.dataDirectoryPath,
    required this.databasePath,
    required this.receiptsImageDirectoryPath,
    required this.extractBaseUri,
  });

  final int port;
  final String dataDirectoryPath;
  final String databasePath;
  final String receiptsImageDirectoryPath;
  final Uri extractBaseUri;

  factory BackendConfig.fromEnvironment(Map<String, String> environment) {
    final dataDirectoryPath =
        environment['RIS_BACKEND_DATA_DIR'] ?? path.join(path.current, 'data');
    final databasePath =
        environment['RIS_BACKEND_DB_PATH'] ??
        path.join(dataDirectoryPath, 'ris_backend.sqlite');
    final receiptsImageDirectoryPath =
        environment['RIS_BACKEND_RECEIPTS_IMAGE_DIR'] ??
        path.join(dataDirectoryPath, 'receipts');
    final portValue = environment['PORT'] ?? '8080';
    final port = int.tryParse(portValue);
    if (port == null) {
      throw ConfigurationException('Invalid PORT value: $portValue.');
    }

    final extractBaseUrl =
        environment['RIS_EXTRACT_BASE_URL'] ?? 'http://127.0.0.1:8081';
    final extractBaseUri = Uri.tryParse(extractBaseUrl);
    if (extractBaseUri == null ||
        !extractBaseUri.hasScheme ||
        !extractBaseUri.hasAuthority) {
      throw ConfigurationException(
        'Invalid RIS_EXTRACT_BASE_URL value: $extractBaseUrl.',
      );
    }

    return BackendConfig(
      port: port,
      dataDirectoryPath: dataDirectoryPath,
      databasePath: databasePath,
      receiptsImageDirectoryPath: receiptsImageDirectoryPath,
      extractBaseUri: extractBaseUri,
    );
  }
}
