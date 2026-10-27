import 'package:flutter_test/flutter_test.dart';
import 'package:pitch_manager/core/domain/revenue_calculator.dart';
import 'package:pitch_manager/core/models/reservation.dart';
import 'package:pitch_manager/core/models/sale.dart';

import 'helpers.dart';

void main() {
  final monday = testWeekStart;
  final nextMonday = DateTime(2026, 11, 2);

  group('summarize', () {
    test('adds up reservations and canteen sales', () {
      final reservations = [
        reservation('a', DateTime(2026, 10, 26, 18)),
        reservation('b', DateTime(2026, 10, 27, 19), hours: 2),
      ];
      final sales = [sale('s1', DateTime(2026, 10, 27, 20))]; // 2 x 2.00
      final s = RevenueCalculator.summarize(reservations, sales, monday, nextMonday);

      expect(s.reservationRevenue, 120);
      expect(s.canteenRevenue, 4);
      expect(s.total, 124);
      expect(s.bookingCount, 2);
      expect(s.bookedHours, 3);
      expect(s.salesCount, 1);
      expect(s.itemsSold, 2);
    });

    test('ignores cancelled reservations and voided sales', () {
      final reservations = [
        reservation('a', DateTime(2026, 10, 26, 18)),
        reservation('b', DateTime(2026, 10, 26, 19), status: ReservationStatus.cancelled),
      ];
      final sales = [
        sale('s1', DateTime(2026, 10, 26, 20)),
        sale('s2', DateTime(2026, 10, 26, 21), voided: true),
      ];
      final s = RevenueCalculator.summarize(reservations, sales, monday, nextMonday);

      expect(s.bookingCount, 1);
      expect(s.reservationRevenue, 40);
      expect(s.salesCount, 1);
      expect(s.canteenRevenue, 4);
    });

    test('the range is half-open: start included, end excluded', () {
      final reservations = [
        reservation('first', monday.add(const Duration(hours: 10))),
        reservation('edge', DateTime(2026, 11, 2, 0)),
      ];
      final s = RevenueCalculator.summarize(reservations, const [], monday, nextMonday);
      expect(s.bookingCount, 1);
    });

    test('ranks products by revenue and merges lines of the same product', () {
      final sales = [
        sale('s1', DateTime(2026, 10, 26, 12), lines: const [
          SaleLine(productId: 'w', productName: 'Water', unitPrice: 2, quantity: 1),
          SaleLine(productId: 'c', productName: 'Coffee', unitPrice: 3, quantity: 5),
        ]),
        sale('s2', DateTime(2026, 10, 27, 12), lines: const [
          SaleLine(productId: 'w', productName: 'Water', unitPrice: 2, quantity: 2),
        ]),
      ];
      final s = RevenueCalculator.summarize(const [], sales, monday, nextMonday);

      expect(s.topProducts.map((p) => p.name), ['Coffee', 'Water']);
      expect(s.topProducts.first.revenue, 15);
      expect(s.topProducts.last.quantity, 3);
      expect(s.itemsSold, 8);
    });

    test('empty input gives zeros', () {
      final s = RevenueCalculator.summarize(const [], const [], monday, nextMonday);
      expect(s.total, 0);
      expect(s.topProducts, isEmpty);
    });
  });

  group('byDay', () {
    test('one bucket per day, totals add up to the summary', () {
      final reservations = [
        reservation('a', DateTime(2026, 10, 26, 18)),
        reservation('b', DateTime(2026, 10, 28, 18), hours: 2),
      ];
      final sales = [sale('s', DateTime(2026, 10, 28, 12))];
      final buckets = RevenueCalculator.byDay(reservations, sales, monday, nextMonday);

      expect(buckets, hasLength(7));
      expect(buckets.first.reservations, 40);
      expect(buckets[2].reservations, 80);
      expect(buckets[2].canteen, 4);
      expect(buckets[1].total, 0);
      final sum = buckets.fold<double>(0, (s, b) => s + b.total);
      final summary = RevenueCalculator.summarize(reservations, sales, monday, nextMonday);
      expect(sum, summary.total);
    });

    test('handles months of different lengths', () {
      final buckets = RevenueCalculator.byDay(
          const [], const [], DateTime(2026, 2), DateTime(2026, 3));
      expect(buckets, hasLength(28));
    });
  });

  group('byHour', () {
    test('attributes a reservation to its starting hour', () {
      final day = DateTime(2026, 10, 27);
      final buckets = RevenueCalculator.byHour(
        [reservation('a', DateTime(2026, 10, 27, 18), hours: 2)],
        [sale('s', DateTime(2026, 10, 27, 18, 40))],
        day,
        firstHour: 10,
        lastHour: 24,
      );
      expect(buckets, hasLength(14));
      final at18 = buckets.firstWhere((b) => b.start.hour == 18);
      expect(at18.reservations, 80);
      expect(at18.canteen, 4);
      expect(buckets.firstWhere((b) => b.start.hour == 19).total, 0);
    });

    test('widens the range when a sale happens outside opening hours', () {
      final day = DateTime(2026, 10, 27);
      final buckets = RevenueCalculator.byHour(
        const [],
        [sale('late', DateTime(2026, 10, 27, 8, 15))],
        day,
        firstHour: 10,
        lastHour: 24,
      );
      expect(buckets.first.start.hour, 8);
      expect(buckets.fold<double>(0, (s, b) => s + b.canteen), 4);
    });
  });

  group('percentChange', () {
    test('computes growth and decline', () {
      expect(RevenueCalculator.percentChange(150, 100), 50);
      expect(RevenueCalculator.percentChange(50, 100), -50);
    });

    test('is null when there is nothing to compare with', () {
      expect(RevenueCalculator.percentChange(100, 0), isNull);
    });
  });
}
