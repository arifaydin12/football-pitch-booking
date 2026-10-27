import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/state/canteen_controller.dart';
import '../../core/utils/formatters.dart';

/// Cart contents with quantity controls and the checkout button.
class CartPanel extends StatefulWidget {
  const CartPanel({super.key, required this.onCheckout, this.elevated = true});

  /// Called when the user taps "Charge"; the screen performs the sale.
  final Future<void> Function() onCheckout;

  /// Wraps the panel in a card (side panel) or not (bottom sheet).
  final bool elevated;

  @override
  State<CartPanel> createState() => _CartPanelState();
}

class _CartPanelState extends State<CartPanel> {
  bool _busy = false;

  Future<void> _charge() async {
    setState(() => _busy = true);
    try {
      await widget.onCheckout();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<CanteenController>();
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final items = controller.cartItems;

    final content = Column(
      mainAxisSize: widget.elevated ? MainAxisSize.max : MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Semantics(
              header: true,
              child: Text('Cart', style: theme.textTheme.titleMedium),
            ),
            const Spacer(),
            if (items.isNotEmpty)
              TextButton(
                onPressed: _busy ? null : controller.clearCart,
                child: const Text('Clear'),
              ),
          ],
        ),
        const SizedBox(height: 4),
        if (items.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 32),
            child: Column(
              children: [
                Icon(Icons.shopping_cart_outlined, size: 40, color: scheme.outline),
                const SizedBox(height: 8),
                Text('The cart is empty',
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(color: scheme.onSurfaceVariant)),
                Text('Tap a product to add it',
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: scheme.onSurfaceVariant)),
              ],
            ),
          )
        else
          Flexible(
            fit: widget.elevated ? FlexFit.tight : FlexFit.loose,
            child: ListView.separated(
              shrinkWrap: !widget.elevated,
              itemCount: items.length,
              separatorBuilder: (_, _) => const Divider(),
              itemBuilder: (context, index) {
                final item = items[index];
                final p = item.product;
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(p.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.titleSmall),
                            Text('${formatMoney(p.price)} each',
                                style: theme.textTheme.bodySmall?.copyWith(
                                    color: scheme.onSurfaceVariant)),
                          ],
                        ),
                      ),
                      IconButton.outlined(
                        tooltip: 'Remove one ${p.name}',
                        visualDensity: VisualDensity.compact,
                        icon: const Icon(Icons.remove, size: 18),
                        onPressed: _busy
                            ? null
                            : () => controller.removeOneFromCart(p.id),
                      ),
                      SizedBox(
                        width: 32,
                        child: Semantics(
                          label: '${item.quantity} ${p.name} in cart',
                          excludeSemantics: true,
                          child: Text('${item.quantity}',
                              textAlign: TextAlign.center,
                              style: theme.textTheme.titleSmall),
                        ),
                      ),
                      IconButton.outlined(
                        tooltip: 'Add one ${p.name}',
                        visualDensity: VisualDensity.compact,
                        icon: const Icon(Icons.add, size: 18),
                        onPressed: _busy || item.quantity >= p.stock
                            ? null
                            : () => controller.addToCart(p),
                      ),
                      SizedBox(
                        width: 72,
                        child: Text(
                          formatMoney(p.price * item.quantity),
                          textAlign: TextAlign.right,
                          style: theme.textTheme.titleSmall,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        const Divider(),
        const SizedBox(height: 8),
        Row(
          children: [
            Text('Total', style: theme.textTheme.titleMedium),
            const Spacer(),
            Semantics(
              label: 'Total ${formatMoney(controller.cartTotal)}',
              excludeSemantics: true,
              child: Text(
                formatMoney(controller.cartTotal),
                style: theme.textTheme.headlineSmall
                    ?.copyWith(fontWeight: FontWeight.w800),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: items.isEmpty || _busy ? null : _charge,
          icon: _busy
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2.5),
                )
              : const Icon(Icons.payments_outlined),
          label: Text(items.isEmpty ? 'Charge' : 'Charge ${formatMoney(controller.cartTotal)}'),
        ),
      ],
    );

    if (!widget.elevated) return content;
    return Card(
      child: Padding(padding: const EdgeInsets.all(16), child: content),
    );
  }
}
