import 'dart:io';
import 'package:shelf/shelf_io.dart';
import 'package:ris_backend/ris_backend.dart';

void main(List<String> args) async {
  final config = BackendConfig.fromEnvironment(Platform.environment);
  final handler = await buildHandler(config);
  final server = await serve(handler, InternetAddress.anyIPv4, config.port);
  print('Server listening on port ${server.port}');
}
