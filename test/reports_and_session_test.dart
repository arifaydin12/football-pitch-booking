import 'package:flutter_test/flutter_test.dart';
import 'package:pitch_manager/core/data/demo/demo_repositories.dart';
import 'package:pitch_manager/core/models/reservation.dart';
import 'package:pitch_manager/core/state/reports_controller.dart';
import 'package:pitch_manager/core/state/session_controller.dart';
import 'package:pitch_manager/core/state/settings_controller.dart';

import 'helpers.dart';

Future<void> settle() => Future<void>.delayed(Duration.zero);

void main() {
  group('ReportsController', () {
    late ReportsController controller;

    Future<void> create() async {
      final repos = testRepositories(
        reservations: [
          // two weeks ago (Oct 12 - 18)
          reservation('pp', DateTime(2026, 10, 13, 18)),
          // previous week (Oct 19 - 25)
          reservation('p1', DateTime(2026, 10, 20, 18)),
          // this week (Oct 26 - Nov 1)
          reservation('a', DateTime(2026, 10, 26, 18)),
          reservation('b', DateTime(2026, 10, 27, 18), hours: 2),
          reservation('c', DateTime(2026, 10, 27, 20), status: ReservationStatus.cancelled),
        ],
        sales: [
          sale('s0', DateTime(2026, 10, 21, 12)),
          sale('s1', DateTime(2026, 10, 27, 12)),
          sale('s2', DateTime(2026, 10, 27, 13), voided: true),
        ],
      );
      controller = ReportsController(
        reservations: repos.reservations,
        canteen: repos.canteen,
        clock: testClock,
      );
      expect(controller.isLoading, isTrue);
      await settle();
    }

    tearDown(() => controller.dispose());

    test('defaults to the current week', () async {
      await create();
      expect(controller.period, ReportPeriod.week);
      expect(controller.isLoading, isFalse);
      expect(controller.from, DateTime(2026, 10, 26));
      expect(controller.to, DateTime(2026, 11, 2));
      expect(controller.isCurrentPeriod, isTrue);
      expect(controller.canGoForward, isFalse);
      expect(controller.periodLabel, 'Oct 26 - Nov 1');
    });

    test('summarises the week and compares it with the previous one', () async {
      await create();
      final s = controller.summary;
      expect(s.reservationRevenue, 120); // a (40) + b (80); cancelled c ignored
      expect(s.canteenRevenue, 4); // voided sale ignored
      expect(s.total, 124);
      expect(controller.previousSummary.total, 44);
      expect(controller.totalChangePercent, isNull, reason: 'the week is still running');
      expect(controller.buckets, hasLength(7));
      expect(controller.buckets.fold<double>(0, (a, b) => a + b.total), 124);
    });

    test('occupancy is booked hours over open hours', () async {
      await create();
      // 3 booked hours of 7 days x 14 open hours.
      expect(controller.occupancy, closeTo(3 / 98, 0.0001));
    });

    test('day period uses hourly buckets', () async {
      await create();
      controller.setPeriod(ReportPeriod.day);
      await settle();
      expect(controller.from, DateTime(2026, 10, 27));
      expect(controller.buckets, hasLength(14));
      expect(controller.summary.reservationRevenue, 80);
      expect(controller.periodLabel, 'Tuesday, October 27, 2026');
    });

    test('month period spans the whole calendar month', () async {
      await create();
      controller.setPeriod(ReportPeriod.month);
      await settle();
      expect(controller.from, DateTime(2026, 10));
      expect(controller.to, DateTime(2026, 11));
      expect(controller.buckets, hasLength(31));
      expect(controller.summary.bookingCount, 4);
      expect(controller.periodLabel, 'October 2026');
    });

    test('stepping back shows the previous week and allows going forward', () async {
      await create();
      controller.step(-1);
      await settle();
      expect(controller.from, DateTime(2026, 10, 19));
      expect(controller.summary.total, 44);
      expect(controller.totalChangePercent, closeTo(10, 0.001)); // 44 vs 40
      expect(controller.canGoForward, isTrue);
      controller.step(1);
      await settle();
      expect(controller.isCurrentPeriod, isTrue);
    });

    test('goToCurrent returns to today', () async {
      await create();
      controller
        ..step(-3)
        ..goToCurrent();
      await settle();
      expect(controller.from, DateTime(2026, 10, 26));
    });
  });

  group('SessionController', () {
    test('goes from loading to signed out, then signs in and out', () async {
      final auth = DemoAuthRepository();
      final session = SessionController(auth);
      expect(session.status, SessionStatus.loading);
      await settle();
      expect(session.status, SessionStatus.signedOut);

      expect(await session.signIn('staff@pitch.test', DemoAccounts.password), isTrue);
      await settle();
      expect(session.status, SessionStatus.signedIn);
      expect(session.user?.role.label, 'Staff');
      expect(session.busy, isFalse);

      await session.signOut();
      await settle();
      expect(session.status, SessionStatus.signedOut);
      session.dispose();
    });

    test('exposes the error of a failed sign in and clears it', () async {
      final session = SessionController(DemoAuthRepository());
      await settle();
      expect(await session.signIn('staff@pitch.test', 'wrong'), isFalse);
      expect(session.error, 'Incorrect e-mail or password.');
      expect(session.status, SessionStatus.signedOut);
      session.clearError();
      expect(session.error, isNull);
      session.dispose();
    });
  });

  group('SettingsController', () {
    test('parses and validates amounts', () {
      expect(SettingsController.parseAmount('12,5'), 12.5);
      expect(SettingsController.parseAmount(' 40 '), 40);
      expect(SettingsController.parseAmount('abc'), isNull);
      expect(SettingsController.validateAmount(''), isNotNull);
      expect(SettingsController.validateAmount('abc'), isNotNull);
      expect(SettingsController.validateAmount('0'), isNotNull);
      expect(SettingsController.validateAmount('0', allowZero: true), isNull);
      expect(SettingsController.validateAmount('-3'), isNotNull);
      expect(SettingsController.validateAmount('99999999'), isNotNull);
      expect(SettingsController.validateAmount('45.50'), isNull);
    });

    test('streams the rate and saves a new one', () async {
      final repo = DemoSettingsRepository(hourlyRate: 40);
      final controller = SettingsController(repo);
      expect(controller.isLoading, isTrue);
      await settle();
      expect(controller.hourlyRate, 40);
      expect(controller.isLoading, isFalse);
      await controller.setHourlyRate(52.5);
      await settle();
      expect(controller.hourlyRate, 52.5);
      controller.dispose();
    });
  });
}
