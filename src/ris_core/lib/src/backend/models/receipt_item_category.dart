enum ReceiptItemCategory {
  food('FOOD'),
  household('HOUSEHOLD'),
  restaurant('RESTAURANT'),
  health('HEALTH'),
  electronics('ELECTRONICS'),
  other('OTHER');

  const ReceiptItemCategory(this.apiValue);

  final String apiValue;

  static ReceiptItemCategory fromApiValue(String value) {
    return ReceiptItemCategory.values.firstWhere(
      (category) => category.apiValue == value,
    );
  }
}
