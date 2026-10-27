/// Build-time and business configuration.
class AppConfig {
  const AppConfig._();

  /// Run without Firebase, using in-memory seeded repositories.
  ///
  /// Enable with `--dart-define=DEMO_MODE=true`.
  static const bool demoMode = bool.fromEnvironment('DEMO_MODE');

  static const String appName = 'Pitch Manager';

  /// First bookable hour of the day (inclusive, 24h clock).
  static const int openHour = 10;

  /// Closing hour (exclusive). `24` means the pitch closes at midnight.
  static const int closeHour = 24;

  /// Longest reservation a user can create, in hours.
  static const int maxReservationHours = 3;

  /// Price per hour used before an administrator changes it.
  static const double defaultHourlyRate = 40;

  /// Products with a stock level at or below this value are flagged.
  static const int lowStockThreshold = 5;
}
