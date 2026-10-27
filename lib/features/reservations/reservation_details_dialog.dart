import 'package:flutter/material.dart';

import '../../core/models/reservation.dart';
import '../../core/utils/formatters.dart';

enum ReservationDetailsResult { cancel, restore }

/// Shows a reservation and lets the user cancel (or restore) it.
class ReservationDetailsDialog extends StatelessWidget {
  const ReservationDetailsDialog({super.key, required this.reservation});

  final Reservation reservation;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final active = reservation.isActive;

    Widget row(IconData icon, String label, String value) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 20, color: scheme.onSurfaceVariant),
              const SizedBox(width: 12),
              Expanded(
                child: Semantics(
                  label: '$label: $value',
                  excludeSemantics: true,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(label,
                          style: theme.textTheme.labelSmall
                              ?.copyWith(color: scheme.onSurfaceVariant)),
                      Text(value, style: theme.textTheme.bodyLarge),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );

    return AlertDialog(
      title: Row(
        children: [
          Expanded(child: Text(reservation.customerName)),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: active ? scheme.primaryContainer : scheme.errorContainer,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              active ? 'Booked' : 'Cancelled',
              style: theme.textTheme.labelMedium?.copyWith(
                color: active ? scheme.onPrimaryContainer : scheme.onErrorContainer,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: 400,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              row(Icons.event, 'Date', formatFullDate(reservation.start)),
              row(Icons.schedule, 'Time',
                  '${formatTimeRange(reservation.start, reservation.end)} (${reservation.hours} h)'),
              row(Icons.phone_outlined, 'Phone', reservation.customerPhone),
              row(Icons.payments_outlined, 'Price', formatMoney(reservation.price)),
              if (reservation.createdBy != null)
                row(Icons.badge_outlined, 'Booked by', reservation.createdBy!),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
        if (active)
          TextButton.icon(
            style: TextButton.styleFrom(foregroundColor: scheme.error),
            onPressed: () async {
              final confirmed = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Cancel this reservation?'),
                  content: Text(
                    'The hours become available again. You can undo this right afterwards.',
                    style: theme.textTheme.bodyMedium,
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(false),
                      child: const Text('Keep it'),
                    ),
                    FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: scheme.error,
                        foregroundColor: scheme.onError,
                      ),
                      onPressed: () => Navigator.of(context).pop(true),
                      child: const Text('Cancel reservation'),
                    ),
                  ],
                ),
              );
              if (confirmed == true && context.mounted) {
                Navigator.of(context).pop(ReservationDetailsResult.cancel);
              }
            },
            icon: const Icon(Icons.event_busy_outlined),
            label: const Text('Cancel reservation'),
          )
        else
          FilledButton.icon(
            onPressed: () =>
                Navigator.of(context).pop(ReservationDetailsResult.restore),
            icon: const Icon(Icons.restore),
            label: const Text('Restore'),
          ),
      ],
    );
  }
}
