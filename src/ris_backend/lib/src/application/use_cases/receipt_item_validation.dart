import '../../domain/models/receipt.dart';

const itemTotalMismatchWarningCode = 'ITEM_TOTAL_MISMATCH';

List<ReceiptValidationWarning> buildReceiptItemValidationWarnings({
  required double? extractedTotalAmount,
  required List<ReceiptItem> items,
}) {
  if (extractedTotalAmount == null) {
    return const <ReceiptValidationWarning>[];
  }

  final knownItemTotals = items
      .map((item) => item.totalPrice)
      .whereType<double>()
      .toList(growable: false);
  if (knownItemTotals.isEmpty) {
    return const <ReceiptValidationWarning>[];
  }

  final extractedCents = _toCents(extractedTotalAmount);
  final itemTotalCents = knownItemTotals
      .map(_toCents)
      .fold<int>(0, (sum, value) => sum + value);
  if (extractedCents == itemTotalCents) {
    return const <ReceiptValidationWarning>[];
  }

  return const <ReceiptValidationWarning>[
    ReceiptValidationWarning(
      code: itemTotalMismatchWarningCode,
      message: 'Sum of items differs from extracted total amount.',
    ),
  ];
}

int _toCents(double value) => (value * 100).round();
