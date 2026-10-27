import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/models/product.dart';
import '../../core/state/canteen_controller.dart';
import '../../core/utils/formatters.dart';
import '../../shared/widgets/state_views.dart';

/// Icon that roughly matches a product name.
IconData productIcon(String name) {
  final n = name.toLowerCase();
  if (n.contains('water') || n.contains('drink') || n.contains('cola')) {
    return Icons.local_drink_outlined;
  }
  if (n.contains('coffee') || n.contains('tea')) return Icons.coffee_outlined;
  if (n.contains('juice')) return Icons.emoji_food_beverage_outlined;
  if (n.contains('sandwich') || n.contains('toast') || n.contains('burger')) {
    return Icons.lunch_dining_outlined;
  }
  if (n.contains('bar') || n.contains('chocolate') || n.contains('cookie')) {
    return Icons.cookie_outlined;
  }
  if (n.contains('chip') || n.contains('snack')) return Icons.fastfood_outlined;
  return Icons.shopping_basket_outlined;
}

class ProductGrid extends StatelessWidget {
  const ProductGrid({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<CanteenController>();
    final wide = MediaQuery.sizeOf(context).width >= 1000;
    final low = controller.lowStockProducts;
    return CustomScrollView(
      slivers: [
        if (low.isNotEmpty)
          SliverPadding(
            padding: EdgeInsets.fromLTRB(wide ? 24 : 12, 0, wide ? 12 : 12, 8),
            sliver: SliverToBoxAdapter(child: _LowStockBanner(products: low)),
          ),
        SliverPadding(
          padding: EdgeInsets.fromLTRB(wide ? 24 : 12, 0, wide ? 12 : 12, 16),
          sliver: SliverGrid.builder(
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 190,
              mainAxisExtent: 128,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
            ),
            itemCount: controller.products.length,
            itemBuilder: (context, index) {
              final product = controller.products[index];
              return _ProductTile(
                product: product,
                inCart: controller.quantityInCart(product.id),
                onTap: () {
                  final added = controller.addToCart(product);
                  if (!added) {
                    showMessage(context, 'No more ${product.name} in stock.',
                        isError: true);
                  }
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

class _LowStockBanner extends StatelessWidget {
  const _LowStockBanner({required this.products});

  final List<Product> products;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = products
        .map((p) => p.isOutOfStock ? '${p.name} (out)' : '${p.name} (${p.stock})')
        .join(', ');
    return Semantics(
      container: true,
      label: 'Low stock: $text',
      child: ExcludeSemantics(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: scheme.tertiaryContainer,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Icon(Icons.warning_amber_rounded,
                  size: 20, color: scheme.onTertiaryContainer),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Low stock: $text',
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(color: scheme.onTertiaryContainer),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProductTile extends StatelessWidget {
  const _ProductTile({
    required this.product,
    required this.inCart,
    required this.onTap,
  });

  final Product product;
  final int inCart;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final out = product.isOutOfStock;

    final stockText = out ? 'Out of stock' : '${product.stock} in stock';
    final label =
        '${product.name}, ${formatMoney(product.price)}, $stockText${inCart > 0 ? ', $inCart in cart' : ''}.${out ? '' : ' Tap to add to cart'}';

    return Semantics(
      button: true,
      enabled: !out,
      label: label,
      excludeSemantics: true,
      onTap: out ? null : onTap,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: Material(
              color: out
                  ? scheme.surfaceContainerHighest.withValues(alpha: 0.4)
                  : (inCart > 0
                      ? scheme.primaryContainer
                      : scheme.surfaceContainerLow),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(
                    color: inCart > 0 ? scheme.primary : scheme.outlineVariant),
              ),
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: out ? null : onTap,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(productIcon(product.name),
                          size: 28,
                          color: out ? scheme.outline : scheme.primary),
                      const Spacer(),
                      Text(
                        product.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleSmall?.copyWith(
                          color: out ? scheme.outline : null,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Flexible(
                            child: Text(formatMoney(product.price),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                    color: out ? scheme.outline : null)),
                          ),
                          const Spacer(),
                          if (out)
                            StatusChip(
                              label: 'Out',
                              background: scheme.errorContainer,
                              foreground: scheme.onErrorContainer,
                            )
                          else if (product.isLowStock)
                            StatusChip(
                              label: '${product.stock} left',
                              background: scheme.tertiaryContainer,
                              foreground: scheme.onTertiaryContainer,
                            )
                          else
                            Text('${product.stock} in stock',
                                maxLines: 1,
                                style: theme.textTheme.labelSmall?.copyWith(
                                    color: scheme.onSurfaceVariant)),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          if (inCart > 0)
            Positioned(
              top: -6,
              right: -6,
              child: CircleAvatar(
                radius: 13,
                backgroundColor: scheme.primary,
                child: Text('$inCart',
                    style: TextStyle(
                        fontSize: 12,
                        color: scheme.onPrimary,
                        fontWeight: FontWeight.w800)),
              ),
            ),
        ],
      ),
    );
  }
}
