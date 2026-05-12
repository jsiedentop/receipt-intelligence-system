import 'package:nanoid2/nanoid2.dart';

extension type ReceiptId(String value) {
  static ReceiptId create() {
    final id = nanoid(length: 14);
    return ReceiptId('rcp_$id');
  }
}
