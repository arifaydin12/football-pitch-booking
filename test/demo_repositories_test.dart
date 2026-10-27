import 'package:flutter_test/flutter_test.dart';
import 'package:pitch_manager/core/data/demo/demo_repositories.dart';
import 'package:pitch_manager/core/data/demo/demo_seed.dart';
import 'package:pitch_manager/core/models/app_user.dart';
import 'package:pitch_manager/core/models/product.dart';
import 'package:pitch_manager/core/models/reservation.dart';
import 'package:pitch_manager/core/repositories/repositories.dart';

import 'helpers.dart';

void main() {
  final from = DateTime(2026, 10, 26);
  final to = DateTime(2026, 11, 2);

  group('DemoReservationRepository', () {
    late DemoReservationRepository repo;
    setUp(() => repo = DemoReservationRepository());

    Future<Reservation> book(DateTime start, {int hours = 1}) => repo.create(
          start: start,
          hours: hours,
          customerName: 'Ann',
          customerPhone: '+1 555 0100',
          price: 40.0 * hours,
        );

    test('creates a reservation and streams it', () async {
      final stream = repo.watchRange(from, to);
      expect(await stream.first, isEmpty);
      await book(DateTime(2026, 10, 27, 18));
      final list = await repo.watchRange(from, to).first;
      expect(list, hasLength(1));
      expect(list.single.customerName, 'Ann');
    });

    test('emits updates to existing listeners', () async {
      final emissions = <int>[];
      final sub = repo.watchRange(from, to).listen((l) => emissions.add(l.length));
      await Future<void>.delayed(Duration.zero);
      await book(DateTime(2026, 10, 27, 18));
      await Future<void>.delayed(Duration.zero);
      await sub.cancel();
      expect(emissions, [0, 1]);
    });

    test('rejects overlapping bookings', () async {
      await book(DateTime(2026, 10, 27, 18), hours: 2);
      expect(() => book(DateTime(2026, 10, 27, 19)), throwsA(isA<SlotUnavailableException>()));
      expect(() => book(DateTime(2026, 10, 27, 17), hours: 2),
          throwsA(isA<SlotUnavailableException>()));
      // Adjacent hours are fine.
      await book(DateTime(2026, 10, 27, 20));
      await book(DateTime(2026, 10, 27, 17));
    });

    test('filters by range', () async {
      await book(DateTime(2026, 10, 27, 18));
      await book(DateTime(2026, 11, 5, 18));
      final list = await repo.watchRange(from, to).first;
      expect(list, hasLength(1));
    });

    test('cancelling frees the hours and restoring takes them again', () async {
      final created = await book(DateTime(2026, 10, 27, 18));
      await repo.cancel(created);
      expect((await repo.watchRange(from, to).first).single.isActive, isFalse);

      final replacement = await book(DateTime(2026, 10, 27, 18));
      expect(replacement.id, isNot(created.id));

      // The hours were taken meanwhile, so restoring must fail.
      expect(() => repo.restore(created), throwsA(isA<SlotUnavailableException>()));

      await repo.cancel(replacement);
      await repo.restore(created);
      final active = (await repo.watchRange(from, to).first).where((r) => r.isActive);
      expect(active.single.id, created.id);
    });
  });

  group('DemoCanteenRepository', () {
    late DemoCanteenRepository repo;
    setUp(() {
      repo = DemoCanteenRepository(products: testProducts, clock: testClock);
    });

    Future<Product> product(String id) async =>
        (await repo.watchProducts().first).firstWhere((p) => p.id == id);

    test('checkout decrements stock and records the sale', () async {
      final water = await product('p1');
      final sale = await repo.checkout(
        [CartItem(product: water, quantity: 3)],
        soldBy: 'Sam',
      );
      expect(sale.total, 6);
      expect(sale.soldAt, testNow);
      expect(sale.soldBy, 'Sam');
      expect((await product('p1')).stock, 7);
      final sales = await repo.watchSales(DateTime(2026, 10, 27), DateTime(2026, 10, 28)).first;
      expect(sales.single.id, sale.id);
    });

    test('fails atomically when any item is short on stock', () async {
      final water = await product('p1');
      final coffee = await product('p2'); // 3 in stock
      await expectLater(
        repo.checkout([
          CartItem(product: water, quantity: 2),
          CartItem(product: coffee, quantity: 4),
        ]),
        throwsA(isA<InsufficientStockException>()),
      );
      expect((await product('p1')).stock, 10, reason: 'nothing may change');
      expect((await product('p2')).stock, 3);
      expect(await repo.watchSales(DateTime(2026), DateTime(2027)).first, isEmpty);
    });

    test('voiding a sale returns the stock exactly once', () async {
      final water = await product('p1');
      final sale = await repo.checkout([CartItem(product: water, quantity: 4)]);
      expect((await product('p1')).stock, 6);

      await repo.voidSale(sale);
      expect((await product('p1')).stock, 10);
      await repo.voidSale(sale);
      expect((await product('p1')).stock, 10, reason: 'second void is a no-op');

      final sales = await repo.watchSales(DateTime(2026), DateTime(2027)).first;
      expect(sales.single.voided, isTrue);
    });

    test('adds, updates and deletes products', () async {
      final added = await repo.addProduct(name: 'Tea', price: 2, stock: 5);
      expect((await repo.watchProducts().first).map((p) => p.name), contains('Tea'));
      await repo.updateProduct(added.copyWith(price: 2.5, stock: 9));
      final updated = await product(added.id);
      expect(updated.price, 2.5);
      expect(updated.stock, 9);
      await repo.deleteProduct(added.id);
      expect((await repo.watchProducts().first).any((p) => p.id == added.id), isFalse);
    });

    test('products are listed alphabetically', () async {
      final names = (await repo.watchProducts().first).map((p) => p.name).toList();
      expect(names, [...names]..sort());
    });
  });

  group('DemoAuthRepository', () {
    late DemoAuthRepository auth;
    setUp(() => auth = DemoAuthRepository());

    test('signs in with a demo account and announces it', () async {
      final states = <AppUser?>[];
      final sub = auth.authStateChanges().listen(states.add);
      final user = await auth.signIn(' ADMIN@pitch.test ', DemoAccounts.password);
      await Future<void>.delayed(Duration.zero);
      expect(user.role, UserRole.admin);
      expect(states, [null, DemoAccounts.admin]);
      await auth.signOut();
      await Future<void>.delayed(Duration.zero);
      expect(states.last, isNull);
      await sub.cancel();
    });

    test('rejects a wrong password and an unknown user with the same message', () async {
      final wrongPassword = await auth
          .signIn('admin@pitch.test', 'nope')
          .then<String>((_) => 'ok', onError: (Object e) => e.toString());
      final unknown = await auth
          .signIn('who@pitch.test', 'demo1234')
          .then<String>((_) => 'ok', onError: (Object e) => e.toString());
      expect(wrongPassword, 'Incorrect e-mail or password.');
      expect(unknown, wrongPassword);
    });

    test('creates users and rejects duplicates and weak passwords', () async {
      final created = await auth.createUser(
          email: 'New@pitch.test', password: 'secret1', role: UserRole.staff, displayName: 'New');
      expect(created.email, 'new@pitch.test');
      expect((await auth.listUsers()), hasLength(3));
      expect(
        () => auth.createUser(email: 'new@pitch.test', password: 'secret1', role: UserRole.staff),
        throwsA(isA<AuthFailure>()),
      );
      expect(
        () => auth.createUser(email: 'x@pitch.test', password: '123', role: UserRole.staff),
        throwsA(isA<AuthFailure>()),
      );
      // The new account can sign in.
      expect((await auth.signIn('new@pitch.test', 'secret1')).uid, created.uid);
    });

    test('an administrator cannot delete their own account', () async {
      await auth.signIn('admin@pitch.test', DemoAccounts.password);
      expect(() => auth.deleteUser(DemoAccounts.admin.uid), throwsA(isA<AuthFailure>()));
      await auth.deleteUser(DemoAccounts.staff.uid);
      expect((await auth.listUsers()).map((u) => u.uid), [DemoAccounts.admin.uid]);
    });
  });

  group('DemoSettingsRepository', () {
    test('streams the hourly rate and updates', () async {
      final settings = DemoSettingsRepository(hourlyRate: 40);
      expect(await settings.watchHourlyRate().first, 40);
      await settings.setHourlyRate(55);
      expect(await settings.watchHourlyRate().first, 55);
    });
  });

  group('DemoSeed', () {
    test('is deterministic and covers the weeks around today', () {
      final a = DemoSeed.generate(testNow);
      final b = DemoSeed.generate(testNow);
      expect(a.reservations.length, b.reservations.length);
      expect(a.sales.length, b.sales.length);
      expect(a.reservations.first.start, b.reservations.first.start);

      final days = a.reservations.map((r) => DateTime(r.start.year, r.start.month, r.start.day)).toSet();
      expect(days.length, greaterThan(30));
      // Every day this week has something booked.
      for (var i = 0; i < 7; i++) {
        final day = DateTime(2026, 10, 26 + i);
        expect(days, contains(day), reason: 'day $day');
      }
    });

    test('never double-books an hour', () {
      final seed = DemoSeed.generate(testNow);
      final taken = <DateTime>{};
      for (final r in seed.reservations.where((r) => r.isActive)) {
        for (final slot in r.slotStarts) {
          expect(taken.add(slot), isTrue, reason: 'duplicate slot $slot');
        }
      }
    });

    test('has sales only up to now and shows low and empty stock', () {
      final seed = DemoSeed.generate(testNow);
      expect(seed.sales.every((s) => !s.soldAt.isAfter(testNow)), isTrue);
      expect(seed.products.any((p) => p.isLowStock), isTrue);
      expect(seed.products.any((p) => p.isOutOfStock), isTrue);
    });
  });
}
