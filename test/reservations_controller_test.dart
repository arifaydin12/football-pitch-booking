import 'package:flutter_test/flutter_test.dart';
import 'package:pitch_manager/core/data/demo/demo_repositories.dart';
import 'package:pitch_manager/core/models/reservation.dart';
import 'package:pitch_manager/core/repositories/repositories.dart';
import 'package:pitch_manager/core/state/reservations_controller.dart';

import 'helpers.dart';

Future<void> settle() => Future<void>.delayed(Duration.zero);

bool _created = false;

void main() {
  late DemoReservationRepository repo;
  late DemoSettingsRepository settings;
  late ReservationsController controller;

  Future<ReservationsController> create([List<Reservation> initial = const []]) async {
    repo = DemoReservationRepository(initial: initial);
    settings = DemoSettingsRepository(hourlyRate: 40);
    controller = ReservationsController(
        reservations: repo, settings: settings, clock: testClock);
    _created = true;
    await settle();
    return controller;
  }

  tearDown(() {
    // Only the tests that created a controller have one to dispose.
    if (_created) controller.dispose();
    _created = false;
  });

  test('starts on today, loads the week and leaves the loading state', () async {
    await create([
      reservation('a', DateTime(2026, 10, 27, 18)),
      reservation('far', DateTime(2026, 11, 20, 18)),
    ]);
    expect(controller.focusedDay, DateTime(2026, 10, 27));
    expect(controller.isLoading, isFalse);
    expect(controller.weekStart, DateTime(2026, 10, 26));
    expect(controller.weekDays, hasLength(7));
    expect(controller.all.map((r) => r.id), ['a']);
  });

  test('is loading until the first snapshot arrives', () {
    repo = DemoReservationRepository();
    settings = DemoSettingsRepository();
    controller = ReservationsController(reservations: repo, settings: settings, clock: testClock);
    _created = true;
    expect(controller.isLoading, isTrue);
  });

  group('booking', () {
    test('prices a booking from the hourly rate and the duration', () async {
      await create();
      final r = await controller.book(
        start: DateTime(2026, 10, 27, 18),
        hours: 2,
        customerName: '  Ann Lee ',
        customerPhone: ' +1 555 0100 ',
        createdBy: 'Sam',
      );
      expect(r.price, 80);
      expect(r.customerName, 'Ann Lee');
      expect(r.customerPhone, '+1 555 0100');
      await settle();
      expect(controller.reservationAt(DateTime(2026, 10, 27, 19))?.id, r.id);
      expect(controller.occupancy(DateTime(2026, 10, 27)).booked, 2);
      expect(controller.bookedRevenueOn(DateTime(2026, 10, 27)), 80);
    });

    test('uses the new rate after an administrator changes it', () async {
      await create();
      await settings.setHourlyRate(55);
      await settle();
      expect(controller.hourlyRate, 55);
      expect(controller.priceFor(3), 165);
      final r = await controller.book(
          start: DateTime(2026, 10, 27, 18),
          hours: 1,
          customerName: 'Ann',
          customerPhone: '+1 555 0100');
      expect(r.price, 55);
    });

    test('rejects double bookings, past slots and out-of-hours requests', () async {
      await create([reservation('a', DateTime(2026, 10, 27, 18))]);
      Future<void> attempt(DateTime start, int hours) => controller.book(
          start: start, hours: hours, customerName: 'Ann', customerPhone: '+1 555 0100');

      await expectLater(attempt(DateTime(2026, 10, 27, 18), 1), throwsA(isA<SlotUnavailableException>()));
      await expectLater(attempt(DateTime(2026, 10, 27, 17), 2), throwsA(isA<SlotUnavailableException>()));
      await expectLater(attempt(DateTime(2026, 10, 27, 11), 1), throwsArgumentError); // past (12:30 now)
      await expectLater(attempt(DateTime(2026, 10, 27, 23), 2), throwsArgumentError); // after closing
      await expectLater(attempt(DateTime(2026, 10, 28, 20), 4), throwsArgumentError); // too long
    });

    test('the current hour can still be booked, earlier hours cannot', () async {
      await create();
      expect(controller.isPast(DateTime(2026, 10, 27, 11)), isTrue);
      expect(controller.isPast(DateTime(2026, 10, 27, 12)), isFalse);
      expect(controller.isBookable(DateTime(2026, 10, 27, 12)), isTrue);
      expect(controller.isBookable(DateTime(2026, 10, 27, 11)), isFalse);
    });

    test('maxHoursFrom stops at the next booking and at closing time', () async {
      await create([reservation('a', DateTime(2026, 10, 28, 15))]);
      expect(controller.maxHoursFrom(DateTime(2026, 10, 28, 12)), 3);
      expect(controller.maxHoursFrom(DateTime(2026, 10, 28, 14)), 1);
      expect(controller.maxHoursFrom(DateTime(2026, 10, 28, 15)), 0);
      expect(controller.maxHoursFrom(DateTime(2026, 10, 28, 23)), 1);
      expect(controller.maxHoursFrom(DateTime(2026, 10, 28, 22)), 2);
    });
  });

  group('cancel and undo', () {
    test('cancelling frees the slot and restoring books it again', () async {
      await create([reservation('a', DateTime(2026, 10, 27, 18), name: 'Ann')]);
      final r = controller.reservationAt(DateTime(2026, 10, 27, 18))!;

      await controller.cancel(r);
      await settle();
      expect(controller.reservationAt(DateTime(2026, 10, 27, 18)), isNull);
      expect(controller.cancelledOn(DateTime(2026, 10, 27)).single.customerName, 'Ann');
      expect(controller.activeOn(DateTime(2026, 10, 27)), isEmpty);
      expect(controller.bookedRevenueOn(DateTime(2026, 10, 27)), 0);

      await controller.restore(controller.cancelledOn(DateTime(2026, 10, 27)).single);
      await settle();
      expect(controller.reservationAt(DateTime(2026, 10, 27, 18)), isNotNull);
    });

    test('restoring fails when someone booked the hours in the meantime', () async {
      await create([reservation('a', DateTime(2026, 10, 27, 18))]);
      final original = controller.all.single;
      await controller.cancel(original);
      await controller.book(
          start: DateTime(2026, 10, 27, 18),
          hours: 1,
          customerName: 'Bob',
          customerPhone: '+1 555 0111');
      await expectLater(controller.restore(original), throwsA(isA<SlotUnavailableException>()));
    });
  });

  group('navigation', () {
    test('selecting a day in another week loads that week', () async {
      await create([
        reservation('this', DateTime(2026, 10, 27, 18)),
        reservation('next', DateTime(2026, 11, 3, 18)),
      ]);
      controller.selectDay(DateTime(2026, 11, 3));
      expect(controller.isLoading, isTrue);
      await settle();
      expect(controller.weekStart, DateTime(2026, 11, 2));
      expect(controller.all.map((r) => r.id), ['next']);
    });

    test('step moves by a day or a week depending on the view', () async {
      await create();
      controller.step(1);
      expect(controller.focusedDay, DateTime(2026, 10, 28));
      controller.setView(ScheduleView.week);
      controller.step(-1);
      expect(controller.focusedDay, DateTime(2026, 10, 21));
      await settle();
      controller.goToToday();
      expect(controller.isToday, isTrue);
    });

    test('notifies listeners when the data changes', () async {
      await create();
      var notifications = 0;
      controller.addListener(() => notifications++);
      await repo.create(
          start: DateTime(2026, 10, 27, 20),
          hours: 1,
          customerName: 'Ann',
          customerPhone: '+1 555 0100',
          price: 40);
      await settle();
      expect(notifications, greaterThan(0));
    });
  });

  group('validators', () {
    test('name', () {
      expect(ReservationValidators.name(''), isNotNull);
      expect(ReservationValidators.name('  '), isNotNull);
      expect(ReservationValidators.name('A'), isNotNull);
      expect(ReservationValidators.name('Al'), isNull);
    });

    test('phone', () {
      expect(ReservationValidators.phone(''), isNotNull);
      expect(ReservationValidators.phone('abc'), isNotNull);
      expect(ReservationValidators.phone('12345'), isNotNull);
      expect(ReservationValidators.phone('+1 (555) 010-0199'), isNull);
      expect(ReservationValidators.phone('5550100'), isNull);
      expect(ReservationValidators.phone('1234567890123456'), isNotNull);
    });
  });
}
