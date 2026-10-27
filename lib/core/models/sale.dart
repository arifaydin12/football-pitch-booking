/// One product line of a [Sale].
class SaleLine {
  const SaleLine({
    required this.productId,
    required this.productName,
    required this.unitPrice,
    required this.quantity,
  });

  final String productId;
  final String productName;
  final double unitPrice;
  final int quantity;

  double get total => unitPrice * quantity;
}

/// A completed canteen checkout. Voided sales stay in the history but are
/// excluded from revenue and their stock is returned.
class Sale {
  const Sale({
    required this.id,
    required this.soldAt,
    required this.lines,
    this.voided = false,
    this.soldBy,
  });

  final String id;
  final DateTime soldAt;
  final List<SaleLine> lines;
  final bool voided;
  final String? soldBy;

  double get total => lines.fold(0, (sum, line) => sum + line.total);
  int get itemCount => lines.fold(0, (sum, line) => sum + line.quantity);

  Sale copyWith({bool? voided}) => Sale(
        id: id,
        soldAt: soldAt,
        lines: lines,
        voided: voided ?? this.voided,
        soldBy: soldBy,
      );
}
