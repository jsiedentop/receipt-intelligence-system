import 'package:nanoid2/nanoid2.dart';

extension type MerchantId(String value) {
  static MerchantId create() {
    final id = nanoid(length: 14);
    return MerchantId('mer_$id');
  }
}
