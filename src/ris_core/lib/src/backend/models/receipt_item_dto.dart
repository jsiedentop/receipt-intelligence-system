import 'receipt_item_category.dart';
import 'receipt_response_dto.dart';

class ReceiptItemDto {
  const ReceiptItemDto({
    required this.id,
    required this.itemNumber,
    required this.name,
    required this.totalPrice,
    required this.quantity,
    required this.category,
  });

  final String id;
  final String? itemNumber;
  final String? name;
  final double? totalPrice;
  final int? quantity;
  final ReceiptItemCategory? category;

  factory ReceiptItemDto.fromJson(BackendJsonMap json) {
    return ReceiptItemDto(
      id: json['id'] as String,
      itemNumber: json['itemNumber'] as String?,
      name: json['name'] as String?,
      totalPrice: _asNullableDouble(json['totalPrice']),
      quantity: json['quantity'] as int?,
      category: json['category'] == null
          ? null
          : ReceiptItemCategory.fromApiValue(json['category'] as String),
    );
  }

  BackendJsonMap toJson() {
    return {
      'id': id,
      'itemNumber': itemNumber,
      'name': name,
      'totalPrice': totalPrice,
      'quantity': quantity,
      'category': category?.apiValue,
    };
  }
}

class ReceiptValidationWarningDto {
  const ReceiptValidationWarningDto({
    required this.code,
    required this.message,
  });

  final String code;
  final String message;

  factory ReceiptValidationWarningDto.fromJson(BackendJsonMap json) {
    return ReceiptValidationWarningDto(
      code: json['code'] as String,
      message: json['message'] as String,
    );
  }

  BackendJsonMap toJson() {
    return {'code': code, 'message': message};
  }
}

double? _asNullableDouble(Object? value) {
  if (value == null) {
    return null;
  }
  if (value is num) {
    return value.toDouble();
  }

  throw FormatException('Expected numeric value.');
}
