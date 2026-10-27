import 'package:intl/intl.dart';

const String _locale = 'en_US';

final NumberFormat _currency =
    NumberFormat.currency(locale: _locale, symbol: r'$', decimalDigits: 2);
final NumberFormat _currencyCompact =
    NumberFormat.currency(locale: _locale, symbol: r'$', decimalDigits: 0);
final DateFormat _time = DateFormat('h:mm a', _locale);
final DateFormat _hour = DateFormat('h a', _locale);
final DateFormat _fullDate = DateFormat('EEEE, MMMM d, y', _locale);
final DateFormat _shortDate = DateFormat('MMM d', _locale);
final DateFormat _weekday = DateFormat('EEE', _locale);
final DateFormat _month = DateFormat('MMMM y', _locale);
final DateFormat _dateTime = DateFormat('MMM d, h:mm a', _locale);

/// `$1,234.50`
String formatMoney(num value) => _currency.format(value);

/// `$1,235` - for chart axes and tight spaces.
String formatMoneyCompact(num value) => _currencyCompact.format(value);

/// `6:00 PM`
String formatTime(DateTime d) => _time.format(d);

/// `6 PM`
String formatHour(DateTime d) => _hour.format(d);

/// `6:00 PM - 8:00 PM`
String formatTimeRange(DateTime start, DateTime end) =>
    '${formatTime(start)} - ${formatTime(end)}';

/// `Tuesday, October 27, 2026`
String formatFullDate(DateTime d) => _fullDate.format(d);

/// `Oct 27`
String formatShortDate(DateTime d) => _shortDate.format(d);

/// `Tue`
String formatWeekday(DateTime d) => _weekday.format(d);

/// `October 2026`
String formatMonth(DateTime d) => _month.format(d);

/// `Oct 27, 6:00 PM`
String formatDateTime(DateTime d) => _dateTime.format(d);

/// `Oct 26 - Nov 1`
String formatDateRange(DateTime first, DateTime last) =>
    '${formatShortDate(first)} - ${formatShortDate(last)}';
