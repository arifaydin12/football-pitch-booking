import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/models/app_user.dart';
import '../../core/models/reservation.dart';
import '../../core/repositories/repositories.dart';
import '../../core/state/reservations_controller.dart';
import '../../core/utils/formatters.dart';
import '../../shared/widgets/state_views.dart';
import 'booking_dialog.dart';
import 'reservation_details_dialog.dart';

/// User-initiated reservation flows shared by the day and week views.
class ReservationActions {
  const ReservationActions._();

  /// Opens the booking form for [slot] and, on success, offers an undo.
  static Future<void> book(BuildContext context, DateTime slot) async {
    final controller = context.read<ReservationsController>()
      ..selectDay(slot); // the booking form lists the hours of the focused day
    final created = await showDialog<Reservation>(
      context: context,
      builder: (_) => ChangeNotifierProvider.value(
        value: controller,
        child: Provider<AppUser>.value(
          value: context.read<AppUser>(),
          child: BookingDialog(initialStart: slot),
        ),
      ),
    );
    if (created == null || !context.mounted) return;
    showMessage(
      context,
      'Booked ${formatTimeRange(created.start, created.end)} for ${created.customerName}',
      actionLabel: 'Undo',
      onAction: () => _cancel(context, controller, created, announce: false),
    );
  }

  /// "New reservation" button: first free slot of the focused day.
  static Future<void> bookFirstFree(BuildContext context) async {
    final controller = context.read<ReservationsController>();
    final free = controller.slotsOfFocusedDay.where(controller.isBookable);
    if (free.isEmpty) {
      showMessage(context, 'There are no free hours left on this day.');
      return;
    }
    await book(context, free.first);
  }

  static Future<void> showDetails(BuildContext context, Reservation reservation) async {
    final controller = context.read<ReservationsController>();
    final action = await showDialog<ReservationDetailsResult>(
      context: context,
      builder: (_) => ReservationDetailsDialog(reservation: reservation),
    );
    if (action == null || !context.mounted) return;
    switch (action) {
      case ReservationDetailsResult.cancel:
        await _cancel(context, controller, reservation);
      case ReservationDetailsResult.restore:
        await restore(context, controller, reservation);
    }
  }

  static Future<void> _cancel(
    BuildContext context,
    ReservationsController controller,
    Reservation reservation, {
    bool announce = true,
  }) async {
    try {
      await controller.cancel(reservation);
      if (!context.mounted) return;
      showMessage(
        context,
        announce
            ? 'Cancelled the reservation of ${reservation.customerName}'
            : 'Booking undone',
        actionLabel: announce ? 'Undo' : null,
        onAction: announce
            ? () => restore(context, controller, reservation)
            : null,
      );
    } on RepositoryException catch (e) {
      if (context.mounted) showMessage(context, e.message, isError: true);
    } catch (_) {
      if (context.mounted) {
        showMessage(context, 'Could not cancel the reservation.', isError: true);
      }
    }
  }

  static Future<void> restore(
    BuildContext context,
    ReservationsController controller,
    Reservation reservation,
  ) async {
    try {
      await controller.restore(reservation);
      if (context.mounted) {
        showMessage(context, 'Reservation of ${reservation.customerName} restored');
      }
    } on RepositoryException catch (e) {
      if (context.mounted) showMessage(context, e.message, isError: true);
    } catch (_) {
      if (context.mounted) {
        showMessage(context, 'Could not restore the reservation.', isError: true);
      }
    }
  }
}
