import 'dart:math';

import '../../config/app_config.dart';
import '../../models/product.dart';
import '../../models/reservation.dart';
import '../../models/sale.dart';
import '../../utils/date_utils.dart';

/// Deterministic sample data for demo mode and tests.
///
/// Everything is generated relative to a reference time so the demo always
/// shows a populated "this week".
class DemoSeed {
  DemoSeed._({
    required this.reservations,
    required this.products,
    required this.sales,
  });

  final List<Reservation> reservations;
  final List<Product> products;
  final List<Sale> sales;

  static const List<String> _customers = [
    'Alex Morgan',
    'Ben Carter',
    'Chris Walker',
    'Daniel Reed',
    'Emma Brooks',
    'Frank Turner',
    'Grace Hughes',
    'Henry Wells',
    'Isla Foster',
    'Jack Bennett',
    'Karen Price',
    'Liam Cooper',
    'Mia Scott',
    'Noah Ward',
    'Olivia Grant',
    'Paul Hayes',
  ];

  static const List<Product> _catalog = [
    Product(id: 'p1', name: 'Water 0.5 L', price: 1.5, stock: 48),
    Product(id: 'p2', name: 'Sports drink', price: 3, stock: 30),
    Product(id: 'p3', name: 'Coffee', price: 2.5, stock: 40),
    Product(id: 'p4', name: 'Tea', price: 2, stock: 36),
    Product(id: 'p5', name: 'Toasted sandwich', price: 4.5, stock: 14),
    Product(id: 'p6', name: 'Orange juice', price: 3, stock: 22),
    Product(id: 'p7', name: 'Energy bar', price: 2.5, stock: 4),
    Product(id: 'p8', name: 'Potato chips', price: 2, stock: 0),
  ];

  /// Builds a data set spanning 5 weeks back to 1 week ahead of [now].
  static DemoSeed generate(DateTime now, {int seed = 7, double hourlyRate = AppConfig.defaultHourlyRate}) {
    final random = Random(seed);
    final today = dateOnly(now);
    final reservations = <Reservation>[];
    final sales = <Sale>[];
    var reservationCounter = 0;
    var saleCounter = 0;

    for (var offset = -35; offset <= 7; offset++) {
      final day = addDays(today, offset);
      final weekend = day.weekday >= DateTime.saturday;
      final occupied = <int>{};
      // Busy evenings, quieter afternoons.
      for (var hour = AppConfig.openHour; hour < AppConfig.closeHour; hour++) {
        if (occupied.contains(hour)) continue;
        final evening = hour >= 17 && hour <= 22;
        var chance = evening ? 0.62 : 0.18;
        if (weekend) chance += 0.2;
        if (offset >= 0 && offset <= 3) chance += 0.18; // a busy few days around today
        if (offset > 4) chance -= 0.2; // fewer bookings far in the future
        if (random.nextDouble() > chance) continue;
        final hours = random.nextDouble() < 0.22 &&
                hour + 2 <= AppConfig.closeHour &&
                !occupied.contains(hour + 1)
            ? 2
            : 1;
        for (var i = 0; i < hours; i++) {
          occupied.add(hour + i);
        }
        final customerIndex = random.nextInt(_customers.length);
        final cancelled = random.nextDouble() < 0.08;
        reservations.add(Reservation(
          id: 'r${++reservationCounter}',
          start: DateTime(day.year, day.month, day.day, hour),
          hours: hours,
          customerName: _customers[customerIndex],
          customerPhone: '+1 555 01${(10 + customerIndex).toString().padLeft(2, '0')}',
          price: hourlyRate * hours,
          status: cancelled ? ReservationStatus.cancelled : ReservationStatus.booked,
          createdBy: 'Sam Staff',
        ));
      }

      if (offset > 0) continue;
      final lastHour = offset == 0 ? now.hour : AppConfig.closeHour - 1;
      final count = 5 + random.nextInt(8) + (weekend ? 4 : 0);
      for (var i = 0; i < count; i++) {
        final hour = AppConfig.openHour +
            random.nextInt(max(1, lastHour - AppConfig.openHour + 1));
        if (offset == 0 && hour > now.hour) continue;
        final lineCount = 1 + random.nextInt(3);
        final lines = <SaleLine>[];
        final used = <String>{};
        for (var l = 0; l < lineCount; l++) {
          // Favor the cheap, popular products.
          final product = _catalog[min(random.nextInt(_catalog.length), random.nextInt(_catalog.length))];
          if (!used.add(product.id)) continue;
          lines.add(SaleLine(
            productId: product.id,
            productName: product.name,
            unitPrice: product.price,
            quantity: 1 + random.nextInt(3),
          ));
        }
        // Never sell "in the future" on the current day.
        final minute =
            offset == 0 && hour == now.hour ? random.nextInt(now.minute + 1) : random.nextInt(60);
        sales.add(Sale(
          id: 's${++saleCounter}',
          soldAt: DateTime(day.year, day.month, day.day, hour, minute),
          lines: lines,
          voided: random.nextDouble() < 0.03,
          soldBy: 'Sam Staff',
        ));
      }
    }

    return DemoSeed._(
      reservations: reservations,
      products: List.of(_catalog),
      sales: sales,
    );
  }
}
