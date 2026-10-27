import '../models/reservation.dart';
import '../models/sale.dart';
import '../utils/date_utils.dart';

/// Revenue of one chart bucket (an hour or a day).
class RevenueBucket {
  const RevenueBucket({
    required this.start,
    this.reservations = 0,
    this.canteen = 0,
  });

  final DateTime start;
  final double reservations;
  final double canteen;

  double get total => reservations + canteen;
}

/// Units and revenue of one product within a period.
class ProductSales {
  const ProductSales({
    required this.productId,
    required this.name,
    required this.quantity,
    required this.revenue,
  });

  final String productId;
  final String name;
  final int quantity;
  final double revenue;
}

/// Totals for a period.
class RevenueSummary {
  const RevenueSummary({
    this.reservationRevenue = 0,
    this.canteenRevenue = 0,
    this.bookingCount = 0,
    this.bookedHours = 0,
    this.salesCount = 0,
    this.itemsSold = 0,
    this.topProducts = const [],
  });

  final double reservationRevenue;
  final double canteenRevenue;
  final int bookingCount;
  final int bookedHours;
  final int salesCount;
  final int itemsSold;

  /// Best sellers by revenue, highest first.
  final List<ProductSales> topProducts;

  double get total => reservationRevenue + canteenRevenue;
}

/// Pure revenue calculations. Cancelled reservations and voided sales never
/// count. A reservation is attributed to the day it is played, a sale to the
/// day it is made.
class RevenueCalculator {
  const RevenueCalculator._();

  static bool _inRange(DateTime t, DateTime from, DateTime to) =>
      !t.isBefore(from) && t.isBefore(to);

  static Iterable<Reservation> activeReservations(
          Iterable<Reservation> reservations, DateTime from, DateTime to) =>
      reservations.where((r) => r.isActive && _inRange(r.start, from, to));

  static Iterable<Sale> validSales(Iterable<Sale> sales, DateTime from, DateTime to) =>
      sales.where((s) => !s.voided && _inRange(s.soldAt, from, to));

  /// Totals for `[from, to)`.
  static RevenueSummary summarize(
    Iterable<Reservation> reservations,
    Iterable<Sale> sales,
    DateTime from,
    DateTime to, {
    int topProductCount = 5,
  }) {
    final booked = activeReservations(reservations, from, to).toList();
    final sold = validSales(sales, from, to).toList();

    final perProduct = <String, ProductSales>{};
    var items = 0;
    for (final sale in sold) {
      for (final line in sale.lines) {
        items += line.quantity;
        final existing = perProduct[line.productId];
        perProduct[line.productId] = ProductSales(
          productId: line.productId,
          name: line.productName,
          quantity: (existing?.quantity ?? 0) + line.quantity,
          revenue: (existing?.revenue ?? 0) + line.total,
        );
      }
    }
    final top = perProduct.values.toList()
      ..sort((a, b) => b.revenue.compareTo(a.revenue));

    return RevenueSummary(
      reservationRevenue: booked.fold(0.0, (sum, r) => sum + r.price),
      canteenRevenue: sold.fold(0.0, (sum, s) => sum + s.total),
      bookingCount: booked.length,
      bookedHours: booked.fold(0, (sum, r) => sum + r.hours),
      salesCount: sold.length,
      itemsSold: items,
      topProducts: top.take(topProductCount).toList(),
    );
  }

  /// One bucket per calendar day in `[from, to)`.
  static List<RevenueBucket> byDay(
    Iterable<Reservation> reservations,
    Iterable<Sale> sales,
    DateTime from,
    DateTime to,
  ) {
    final days = <DateTime>[];
    for (var d = dateOnly(from); d.isBefore(to); d = addDays(d, 1)) {
      days.add(d);
    }
    final reservationTotals = <DateTime, double>{};
    for (final r in activeReservations(reservations, from, to)) {
      final key = dateOnly(r.start);
      reservationTotals[key] = (reservationTotals[key] ?? 0) + r.price;
    }
    final canteenTotals = <DateTime, double>{};
    for (final s in validSales(sales, from, to)) {
      final key = dateOnly(s.soldAt);
      canteenTotals[key] = (canteenTotals[key] ?? 0) + s.total;
    }
    return [
      for (final d in days)
        RevenueBucket(
          start: d,
          reservations: reservationTotals[d] ?? 0,
          canteen: canteenTotals[d] ?? 0,
        ),
    ];
  }

  /// One bucket per hour of [day], for hours in `[firstHour, lastHour)`.
  /// Reservations are attributed to their starting hour.
  static List<RevenueBucket> byHour(
    Iterable<Reservation> reservations,
    Iterable<Sale> sales,
    DateTime day, {
    required int firstHour,
    required int lastHour,
  }) {
    // (Parameters are re-assigned below when data falls outside the range.)
    final from = dateOnly(day);
    final to = addDays(from, 1);
    final reservationTotals = <int, double>{};
    for (final r in activeReservations(reservations, from, to)) {
      reservationTotals[r.start.hour] =
          (reservationTotals[r.start.hour] ?? 0) + r.price;
    }
    final canteenTotals = <int, double>{};
    for (final s in validSales(sales, from, to)) {
      canteenTotals[s.soldAt.hour] = (canteenTotals[s.soldAt.hour] ?? 0) + s.total;
    }
    // Widen the range when something was sold outside opening hours so the
    // buckets always add up to the period total.
    final hoursWithData = [...reservationTotals.keys, ...canteenTotals.keys];
    for (final h in hoursWithData) {
      if (h < firstHour) firstHour = h;
      if (h + 1 > lastHour) lastHour = h + 1;
    }
    return [
      for (var h = firstHour; h < lastHour; h++)
        RevenueBucket(
          start: DateTime(from.year, from.month, from.day, h),
          reservations: reservationTotals[h] ?? 0,
          canteen: canteenTotals[h] ?? 0,
        ),
    ];
  }

  /// Relative change from [previous] to [current] in percent, or `null` when
  /// there is no previous value to compare with.
  static double? percentChange(double current, double previous) {
    if (previous == 0) return null;
    return (current - previous) / previous * 100;
  }
}
