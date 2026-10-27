import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app/app_theme.dart';
import '../../core/models/app_user.dart';
import '../../core/repositories/repositories.dart';
import '../../core/state/canteen_controller.dart';
import '../../core/utils/formatters.dart';
import '../../shared/widgets/state_views.dart';
import 'cart_panel.dart';
import 'product_grid.dart';
import 'sales_history.dart';

enum _CanteenTab { sell, sales }

/// Point of sale: tap products to fill the cart, check out, review today's
/// sales and void mistakes.
class CanteenScreen extends StatefulWidget {
  const CanteenScreen({super.key});

  @override
  State<CanteenScreen> createState() => _CanteenScreenState();
}

class _CanteenScreenState extends State<CanteenScreen> {
  _CanteenTab _tab = _CanteenTab.sell;

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<CanteenController>();
    final wide = MediaQuery.sizeOf(context).width >= Breakpoints.medium;

    final Widget body;
    if (controller.error != null) {
      body = ErrorState(
        message: describeError(controller.error),
        onRetry: controller.retry,
      );
    } else if (controller.isLoading) {
      body = const LoadingView(label: 'Loading canteen');
    } else if (_tab == _CanteenTab.sales) {
      body = const SalesHistory();
    } else if (controller.products.isEmpty) {
      body = const EmptyState(
        icon: Icons.inventory_2_outlined,
        title: 'No products yet',
        message: 'An administrator can add products on the Pricing screen.',
      );
    } else if (wide) {
      body = Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Expanded(child: ProductGrid()),
          SizedBox(
            width: 380,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(0, 0, 24, 24),
              child: CartPanel(onCheckout: () => _checkout(context)),
            ),
          ),
        ],
      );
    } else {
      body = Column(
        children: [
          const Expanded(child: ProductGrid()),
          if (!controller.cartIsEmpty) _CartBar(onCheckout: () => _checkout(context)),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(wide ? 24 : 12, 8, wide ? 24 : 12, 8),
          child: Row(
            children: [
              Expanded(
                child: SegmentedButton<_CanteenTab>(
                  showSelectedIcon: false,
                  segments: [
                    const ButtonSegment(
                      value: _CanteenTab.sell,
                      label: Text('Sell'),
                      icon: Icon(Icons.point_of_sale),
                    ),
                    ButtonSegment(
                      value: _CanteenTab.sales,
                      label: Text("Today's sales (${controller.validTodaySales.length})"),
                      icon: const Icon(Icons.receipt_long_outlined),
                    ),
                  ],
                  selected: {_tab},
                  onSelectionChanged: (s) => setState(() => _tab = s.first),
                ),
              ),
              if (wide) const Spacer(flex: 2),
            ],
          ),
        ),
        Expanded(child: body),
      ],
    );
  }

  Future<void> _checkout(BuildContext context) async {
    final controller = context.read<CanteenController>();
    final user = context.read<AppUser>();
    final total = controller.cartTotal;
    try {
      final sale = await controller.checkout(soldBy: user.shownName);
      if (!context.mounted) return;
      showMessage(
        context,
        'Sale of ${formatMoney(total)} completed',
        actionLabel: 'Undo',
        onAction: () async {
          try {
            await controller.voidSale(sale);
            if (context.mounted) showMessage(context, 'Sale undone, stock restored');
          } catch (e) {
            if (context.mounted) {
              showMessage(context, 'Could not undo the sale.', isError: true);
            }
          }
        },
      );
    } on RepositoryException catch (e) {
      if (context.mounted) showMessage(context, e.message, isError: true);
    } catch (_) {
      if (context.mounted) {
        showMessage(context, 'The sale could not be completed.', isError: true);
      }
    }
  }
}

/// Bottom bar on phones that opens the cart.
class _CartBar extends StatelessWidget {
  const _CartBar({required this.onCheckout});

  final Future<void> Function() onCheckout;

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<CanteenController>();
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
      child: Material(
        color: scheme.primary,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => showModalBottomSheet<void>(
            context: context,
            isScrollControlled: true,
            showDragHandle: true,
            builder: (sheetContext) => ChangeNotifierProvider.value(
              value: controller,
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                    16, 0, 16, 16 + MediaQuery.viewInsetsOf(sheetContext).bottom),
                child: CartPanel(
                  elevated: false,
                  onCheckout: () async {
                    Navigator.of(sheetContext).pop();
                    await onCheckout();
                  },
                ),
              ),
            ),
          ),
          child: Semantics(
            button: true,
            label:
                'View cart, ${controller.cartItemCount} items, ${formatMoney(controller.cartTotal)}',
            excludeSemantics: true,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  Icon(Icons.shopping_cart_outlined, color: scheme.onPrimary),
                  const SizedBox(width: 10),
                  Text(
                    '${controller.cartItemCount} items',
                    style: TextStyle(
                        color: scheme.onPrimary, fontWeight: FontWeight.w600),
                  ),
                  const Spacer(),
                  Text(
                    formatMoney(controller.cartTotal),
                    style: TextStyle(
                      color: scheme.onPrimary,
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(Icons.keyboard_arrow_up, color: scheme.onPrimary),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
