import 'package:ris_core/ris_core.dart';

BackendClient buildBackendClient() {
  return BackendClient(
    config: BackendClientConfig(
      baseUri: Uri.parse(
        const String.fromEnvironment(
          'RIS_UI_BACKEND_BASE_URL',
          defaultValue: 'http://127.0.0.1:8080',
        ),
      ),
    ),
  );
}
