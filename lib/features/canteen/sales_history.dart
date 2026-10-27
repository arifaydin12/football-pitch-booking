import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/models/sale.dart';
import '../../core/state/canteen_controller.dart';
import '../../core/utils/formatters.dart';
import '../../shared/widgets/state_views.dart';

/// Today's sales with totals and a "void" action for each sale.
class SalesHistory extends StatelessWidget {
  const SalesHistory({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<CanteenController>();
    final sales = controller.todaySales;
    final wide = MediaQuery.sizeOf(context).width >= 1000;

    if (sales.isEmpty) {
      return const EmptyState(
        icon: Icons.receipt_long_outlined,
        title: 'No sales yet today',
        message: 'Completed sales will appear here.',
      );
    }

    return ListView(
      padding: EdgeInsets.fromLTRB(wide ? 24 : 12, 4, wide ? 24 : 12, 24),
      children: [
        Row(
          children: [
            Expanded(
              child: _Stat(
                label: "Today's canteen revenue",
                value: formatMoney(controller.todayRevenue),
                icon: Icons.payments_outlined,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _Stat(
                label: 'Items sold',
                value: '${controller.todayItemsSold}',
                icon: Icons.shopping_bag_outlined,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        for (final sale in sales) ...[
          _SaleCard(sale: sale, controller: controller),
          const SizedBox(height: 8),
        ],
      ],
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value, required this.icon});

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Semantics(
          label: '$label: $value',
          excludeSemantics: true,
          child: Row(
            children: [
              Icon(icon, color: theme.colorScheme.primary),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label,
                        style: theme.textTheme.labelMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant)),
                    Text(value,
                        style: theme.textTheme.titleLarge
                            ?.copyWith(fontWeight: FontWeight.w800)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SaleCard extends StatelessWidget {
  const _SaleCard({required this.sale, required this.controller});

  final Sale sale;
  final CanteenController controller;

  Future<void> _void(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Void this sale?'),
        content: Text(
            'The sale of ${formatMoney(sale.total)} is removed from revenue and the items return to stock.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Keep it'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Void sale'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await controller.voidSale(sale);
      if (context.mounted) showMessage(context, 'Sale voided, stock restored');
    } catch (_) {
      if (context.mounted) {
        showMessage(context, 'Could not void the sale.', isError: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final summary = sale.lines.map((l) => '${l.quantity} x ${l.productName}').join(', ');
    final voided = sale.voided;
    final strike = voided ? TextDecoration.lineThrough : null;

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
        child: Row(
          children: [
            Icon(voided ? Icons.receipt_outlined : Icons.receipt_long_outlined,
                color: voided ? scheme.outline : scheme.primary),
            const SizedBox(width: 12),
            Expanded(
              child: Semantics(
                label:
                    'Sale at ${formatTime(sale.soldAt)}, $summary, total ${formatMoney(sale.total)}${voided ? ', voided' : ''}',
                excludeSemantics: true,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(formatTime(sale.soldAt),
                            style: theme.textTheme.titleSmall),
                        if (voided) ...[
                          const SizedBox(width: 8),
                          StatusChip(
                            label: 'Voided',
                            background: scheme.errorContainer,
                            foreground: scheme.onErrorContainer,
                          ),
                        ],
                      ],
                    ),
                    Text(
                      summary,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant, decoration: strike),
                    ),
                  ],
                ),
              ),
            ),
            Text(
              formatMoney(sale.total),
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
                decoration: strike,
                color: voided ? scheme.outline : null,
              ),
            ),
            if (!voided)
              IconButton(
                tooltip: 'Void sale of ${formatMoney(sale.total)} at ${formatTime(sale.soldAt)}',
                icon: Icon(Icons.undo, color: scheme.error),
                onPressed: () => _void(context),
              )
            else
              const SizedBox(width: 48),
          ],
        ),
      ),
    );
  }
}
