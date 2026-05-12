import 'package:nanoid2/nanoid2.dart';

extension type ExtractRequestId(String value) {
  static ExtractRequestId create() {
    final id = nanoid(length: 14);
    return ExtractRequestId('ext_$id');
  }

  bool get isValid => value.isNotEmpty && value.startsWith('ext_');
}
