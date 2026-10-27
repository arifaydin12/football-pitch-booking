import '../config/app_config.dart';

/// Date helpers. All dates are local; "days" are calendar days.
DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

bool isSameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

/// Adds calendar days (DST-safe, unlike adding a [Duration]).
DateTime addDays(DateTime d, int days) =>
    DateTime(d.year, d.month, d.day + days);

/// Monday of the week containing [d].
DateTime startOfWeek(DateTime d) =>
    addDays(dateOnly(d), -(d.weekday - DateTime.monday));

DateTime startOfMonth(DateTime d) => DateTime(d.year, d.month);

/// First day of the following month.
DateTime startOfNextMonth(DateTime d) => DateTime(d.year, d.month + 1);

/// The bookable hourly slot start times of [day].
List<DateTime> slotsOfDay(DateTime day) => [
      for (var h = AppConfig.openHour; h < AppConfig.closeHour; h++)
        DateTime(day.year, day.month, day.day, h),
    ];

/// Whether a reservation of [hours] starting at [start] fits inside opening
/// hours of that day.
bool fitsOpeningHours(DateTime start, int hours) =>
    hours >= 1 &&
    start.minute == 0 &&
    start.hour >= AppConfig.openHour &&
    start.hour + hours <= AppConfig.closeHour;
