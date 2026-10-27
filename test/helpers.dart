import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pitch_manager/core/data/demo/demo_repositories.dart';
import 'package:pitch_manager/core/models/product.dart';
import 'package:pitch_manager/core/models/reservation.dart';
import 'package:pitch_manager/core/models/sale.dart';
import 'package:pitch_manager/core/repositories/repositories.dart';

/// A Tuesday at 12:30 - after opening, before the evening slots.
final DateTime testNow = DateTime(2026, 10, 27, 12, 30);

DateTime testClock() => testNow;

/// Midnight of the Monday of [testNow]'s week.
final DateTime testWeekStart = DateTime(2026, 10, 26);

Reservation reservation(
  String id,
  DateTime start, {
  int hours = 1,
  String name = 'Test Customer',
  double? price,
  ReservationStatus status = ReservationStatus.booked,
}) =>
    Reservation(
      id: id,
      start: start,
      hours: hours,
      customerName: name,
      customerPhone: '+1 555 0100',
      price: price ?? 40.0 * hours,
      status: status,
    );

Sale sale(
  String id,
  DateTime at, {
  List<SaleLine>? lines,
  bool voided = false,
}) =>
    Sale(
      id: id,
      soldAt: at,
      voided: voided,
      lines: lines ??
          const [
            SaleLine(productId: 'p1', productName: 'Water', unitPrice: 2, quantity: 2),
          ],
    );

const List<Product> testProducts = [
  Product(id: 'p1', name: 'Water', price: 2, stock: 10),
  Product(id: 'p2', name: 'Coffee', price: 3, stock: 3),
  Product(id: 'p3', name: 'Chips', price: 2.5, stock: 0),
];

AppRepositories testRepositories({
  List<Reservation> reservations = const [],
  List<Product> products = testProducts,
  List<Sale> sales = const [],
}) =>
    AppRepositories(
      auth: DemoAuthRepository(),
      reservations: DemoReservationRepository(initial: reservations),
      canteen: DemoCanteenRepository(products: products, sales: sales, clock: testClock),
      settings: DemoSettingsRepository(hourlyRate: 40),
      isDemo: true,
      clock: testClock,
    );

/// Gives the test a desktop-sized or phone-sized window.
void useScreen(WidgetTester tester, {double width = 1400, double height = 1000}) {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = Size(width, height);
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}
