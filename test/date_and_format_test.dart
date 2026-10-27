import 'package:flutter_test/flutter_test.dart';
import 'package:pitch_manager/core/config/app_config.dart';
import 'package:pitch_manager/core/models/reservation.dart';
import 'package:pitch_manager/core/utils/date_utils.dart';
import 'package:pitch_manager/core/utils/formatters.dart';

import 'helpers.dart';

void main() {
  group('date utils', () {
    test('startOfWeek is the Monday of that week', () {
      expect(startOfWeek(DateTime(2026, 10, 27, 15)), DateTime(2026, 10, 26));
      expect(startOfWeek(DateTime(2026, 10, 26)), DateTime(2026, 10, 26));
      expect(startOfWeek(DateTime(2026, 11, 1, 23, 59)), DateTime(2026, 10, 26));
    });

    test('addDays crosses month and year boundaries', () {
      expect(addDays(DateTime(2026, 12, 31), 1), DateTime(2027, 1, 1));
      expect(addDays(DateTime(2026, 3, 1), -1), DateTime(2026, 2, 28));
    });

    test('slotsOfDay covers the opening hours', () {
      final slots = slotsOfDay(DateTime(2026, 10, 27));
      expect(slots, hasLength(AppConfig.closeHour - AppConfig.openHour));
      expect(slots.first.hour, AppConfig.openHour);
      expect(slots.last.hour, AppConfig.closeHour - 1);
    });

    test('fitsOpeningHours', () {
      expect(fitsOpeningHours(DateTime(2026, 10, 27, 10), 1), isTrue);
      expect(fitsOpeningHours(DateTime(2026, 10, 27, 22), 2), isTrue);
      expect(fitsOpeningHours(DateTime(2026, 10, 27, 23), 2), isFalse);
      expect(fitsOpeningHours(DateTime(2026, 10, 27, 9), 1), isFalse);
      expect(fitsOpeningHours(DateTime(2026, 10, 27, 12, 30), 1), isFalse);
      expect(fitsOpeningHours(DateTime(2026, 10, 27, 12), 0), isFalse);
    });

    test('isSameDay ignores the time of day', () {
      expect(isSameDay(DateTime(2026, 1, 1, 0), DateTime(2026, 1, 1, 23)), isTrue);
      expect(isSameDay(DateTime(2026, 1, 1), DateTime(2026, 1, 2)), isFalse);
    });
  });

  group('formatters (English, USD)', () {
    test('money', () {
      expect(formatMoney(1234.5), r'$1,234.50');
      expect(formatMoney(0), r'$0.00');
      expect(formatMoneyCompact(2500), r'$2,500');
    });

    test('time and dates', () {
      expect(formatTime(DateTime(2026, 10, 27, 18)), '6:00 PM');
      expect(formatTime(DateTime(2026, 10, 27, 0)), '12:00 AM');
      expect(formatFullDate(testNow), 'Tuesday, October 27, 2026');
      expect(formatShortDate(testNow), 'Oct 27');
      expect(formatWeekday(testNow), 'Tue');
      expect(formatMonth(testNow), 'October 2026');
      expect(
        formatTimeRange(DateTime(2026, 10, 27, 18), DateTime(2026, 10, 27, 20)),
        '6:00 PM - 8:00 PM',
      );
    });
  });

  group('Reservation', () {
    test('computes end, slots and overlap', () {
      final r = reservation('a', DateTime(2026, 10, 27, 18), hours: 2);
      expect(r.end, DateTime(2026, 10, 27, 20));
      expect(r.slotStarts, [DateTime(2026, 10, 27, 18), DateTime(2026, 10, 27, 19)]);
      expect(r.overlaps(DateTime(2026, 10, 27, 19), DateTime(2026, 10, 27, 20)), isTrue);
      expect(r.overlaps(DateTime(2026, 10, 27, 20), DateTime(2026, 10, 27, 21)), isFalse);
      expect(r.overlaps(DateTime(2026, 10, 27, 17), DateTime(2026, 10, 27, 18)), isFalse);
    });

    test('copyWith changes only the status', () {
      final r = reservation('a', DateTime(2026, 10, 27, 18));
      final cancelled = r.copyWith(status: ReservationStatus.cancelled);
      expect(cancelled.isActive, isFalse);
      expect(cancelled.customerName, r.customerName);
    });
  });
}
