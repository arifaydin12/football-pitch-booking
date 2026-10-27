enum ReservationStatus {
  booked,
  cancelled;

  static ReservationStatus parse(Object? value) =>
      value == 'cancelled' ? ReservationStatus.cancelled : ReservationStatus.booked;
}

/// A pitch booking of one or more consecutive hourly slots.
class Reservation {
  const Reservation({
    required this.id,
    required this.start,
    required this.hours,
    required this.customerName,
    required this.customerPhone,
    required this.price,
    this.status = ReservationStatus.booked,
    this.createdBy,
  });

  final String id;

  /// Start of the first hour, local time, aligned to the full hour.
  final DateTime start;

  /// Duration in whole hours.
  final int hours;
  final String customerName;
  final String customerPhone;

  /// Total price, fixed at booking time.
  final double price;
  final ReservationStatus status;

  /// Display name of the user who created the booking.
  final String? createdBy;

  DateTime get end => start.add(Duration(hours: hours));
  bool get isActive => status == ReservationStatus.booked;

  /// Start times of every hourly slot this reservation occupies.
  List<DateTime> get slotStarts => [
        for (var i = 0; i < hours; i++)
          DateTime(start.year, start.month, start.day, start.hour + i),
      ];

  bool overlaps(DateTime otherStart, DateTime otherEnd) =>
      start.isBefore(otherEnd) && otherStart.isBefore(end);

  Reservation copyWith({ReservationStatus? status}) => Reservation(
        id: id,
        start: start,
        hours: hours,
        customerName: customerName,
        customerPhone: customerPhone,
        price: price,
        status: status ?? this.status,
        createdBy: createdBy,
      );
}
