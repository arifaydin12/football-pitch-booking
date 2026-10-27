import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app/app_theme.dart';
import '../../core/models/product.dart';
import '../../core/repositories/repositories.dart';
import '../../core/state/canteen_controller.dart';
import '../../core/state/settings_controller.dart';
import '../../core/utils/formatters.dart';
import '../../shared/widgets/state_views.dart';
import '../canteen/product_grid.dart' show productIcon;

/// Pitch hourly rate and canteen product prices / stock (administrators only).
class PricingScreen extends StatelessWidget {
  const PricingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsController>();
    final canteen = context.watch<CanteenController>();
    final wide = MediaQuery.sizeOf(context).width >= Breakpoints.medium;
    final pad = wide ? 24.0 : 12.0;

    if (settings.error != null) {
      return ErrorState(message: describeError(settings.error));
    }
    if (settings.isLoading || canteen.isLoading) {
      return const LoadingView(label: 'Loading prices');
    }

    final rate = _RateCard(settings: settings);
    final products = _ProductsCard(controller: canteen);
    return ListView(
      padding: EdgeInsets.fromLTRB(pad, 8, pad, 24),
      children: [
        if (wide)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(width: 360, child: rate),
              const SizedBox(width: 16),
              Expanded(child: products),
            ],
          )
        else ...[
          rate,
          const SizedBox(height: 16),
          products,
        ],
      ],
    );
  }
}

class _RateCard extends StatelessWidget {
  const _RateCard({required this.settings});

  final SettingsController settings;

  Future<void> _edit(BuildContext context) async {
    final value = await showDialog<double>(
      context: context,
      builder: (_) => _AmountDialog(
        title: 'Hourly pitch rate',
        label: 'Price per hour',
        initial: settings.hourlyRate,
      ),
    );
    if (value == null) return;
    try {
      await settings.setHourlyRate(value);
      if (context.mounted) {
        showMessage(context, 'Hourly rate set to ${formatMoney(value)}');
      }
    } catch (_) {
      if (context.mounted) {
        showMessage(context, 'Could not save the rate.', isError: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.stadium_outlined, color: scheme.primary),
                const SizedBox(width: 8),
                Text('Pitch rental', style: theme.textTheme.titleMedium),
              ],
            ),
            const SizedBox(height: 16),
            Semantics(
              label: 'Current hourly rate ${formatMoney(settings.hourlyRate)}',
              excludeSemantics: true,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Flexible(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        formatMoney(settings.hourlyRate),
                        style: theme.textTheme.displaySmall
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text('per hour',
                        style: theme.textTheme.bodyMedium
                            ?.copyWith(color: scheme.onSurfaceVariant)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'New reservations use this rate. Existing reservations keep the price they were booked at.',
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 16),
            FilledButton.tonalIcon(
              onPressed: () => _edit(context),
              icon: const Icon(Icons.edit_outlined),
              label: const Text('Change rate'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProductsCard extends StatelessWidget {
  const _ProductsCard({required this.controller});

  final CanteenController controller;

  Future<void> _edit(BuildContext context, Product? product) async {
    final result = await showDialog<_ProductForm>(
      context: context,
      builder: (_) => _ProductDialog(product: product),
    );
    if (result == null) return;
    try {
      if (product == null) {
        await controller.addProduct(
            name: result.name, price: result.price, stock: result.stock);
        if (context.mounted) showMessage(context, '${result.name} added');
      } else {
        await controller.updateProduct(product.copyWith(
            name: result.name, price: result.price, stock: result.stock));
        if (context.mounted) showMessage(context, '${result.name} updated');
      }
    } on RepositoryException catch (e) {
      if (context.mounted) showMessage(context, e.message, isError: true);
    } catch (_) {
      if (context.mounted) {
        showMessage(context, 'Could not save the product.', isError: true);
      }
    }
  }

  Future<void> _delete(BuildContext context, Product product) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete ${product.name}?'),
        content: const Text(
            'The product is removed from the canteen. Past sales are kept.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Keep it'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await controller.deleteProduct(product.id);
      if (context.mounted) showMessage(context, '${product.name} deleted');
    } catch (_) {
      if (context.mounted) {
        showMessage(context, 'Could not delete the product.', isError: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final products = controller.products;
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 12, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.local_cafe_outlined, color: scheme.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text('Canteen products',
                      style: theme.textTheme.titleMedium),
                ),
                FilledButton.icon(
                  onPressed: () => _edit(context, null),
                  icon: const Icon(Icons.add),
                  label: const Text('Add product'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (products.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: EmptyState(
                  icon: Icons.inventory_2_outlined,
                  title: 'No products yet',
                  message: 'Add your first product to start selling.',
                ),
              )
            else
              for (final p in products) ...[
                const Divider(),
                _ProductRow(
                  product: p,
                  onEdit: () => _edit(context, p),
                  onDelete: () => _delete(context, p),
                ),
              ],
          ],
        ),
      ),
    );
  }
}

class _ProductRow extends StatelessWidget {
  const _ProductRow({
    required this.product,
    required this.onEdit,
    required this.onDelete,
  });

  final Product product;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final stock = product.isOutOfStock
        ? 'out of stock'
        : '${product.stock} in stock';
    return Semantics(
      container: true,
      label: '${product.name}, ${formatMoney(product.price)}, $stock',
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            ExcludeSemantics(
              child: Icon(productIcon(product.name), color: scheme.onSurfaceVariant),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ExcludeSemantics(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(product.name, style: theme.textTheme.titleSmall),
                    Row(
                      children: [
                        Text(formatMoney(product.price),
                            style: theme.textTheme.bodyMedium),
                        const SizedBox(width: 10),
                        if (product.isOutOfStock)
                          StatusChip(
                            label: 'Out of stock',
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
                              style: theme.textTheme.bodySmall?.copyWith(
                                  color: scheme.onSurfaceVariant)),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            IconButton(
              tooltip: 'Edit ${product.name}',
              icon: const Icon(Icons.edit_outlined),
              onPressed: onEdit,
            ),
            IconButton(
              tooltip: 'Delete ${product.name}',
              icon: Icon(Icons.delete_outline, color: scheme.error),
              onPressed: onDelete,
            ),
          ],
        ),
      ),
    );
  }
}

class _ProductForm {
  const _ProductForm(this.name, this.price, this.stock);
  final String name;
  final double price;
  final int stock;
}

class _ProductDialog extends StatefulWidget {
  const _ProductDialog({this.product});

  final Product? product;

  @override
  State<_ProductDialog> createState() => _ProductDialogState();
}

class _ProductDialogState extends State<_ProductDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name =
      TextEditingController(text: widget.product?.name ?? '');
  late final TextEditingController _price = TextEditingController(
      text: widget.product == null ? '' : widget.product!.price.toStringAsFixed(2));
  late final TextEditingController _stock =
      TextEditingController(text: widget.product?.stock.toString() ?? '');

  @override
  void dispose() {
    _name.dispose();
    _price.dispose();
    _stock.dispose();
    super.dispose();
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.of(context).pop(_ProductForm(
      _name.text.trim(),
      SettingsController.parseAmount(_price.text)!,
      int.parse(_stock.text.trim()),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final isNew = widget.product == null;
    return AlertDialog(
      title: Text(isNew ? 'Add product' : 'Edit product'),
      content: SizedBox(
        width: 400,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _name,
                autofocus: true,
                textCapitalization: TextCapitalization.sentences,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(labelText: 'Name'),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Enter a product name' : null,
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _price,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                textInputAction: TextInputAction.next,
                decoration:
                    const InputDecoration(labelText: 'Price', prefixText: r'$ '),
                validator: SettingsController.validateAmount,
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _stock,
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.done,
                onFieldSubmitted: (_) => _save(),
                decoration: const InputDecoration(labelText: 'Units in stock'),
                validator: (v) {
                  final n = int.tryParse((v ?? '').trim());
                  if (n == null) return 'Enter a whole number';
                  if (n < 0) return 'Stock cannot be negative';
                  if (n > 100000) return 'The number is too large';
                  return null;
                },
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _save, child: const Text('Save')),
      ],
    );
  }
}

class _AmountDialog extends StatefulWidget {
  const _AmountDialog({
    required this.title,
    required this.label,
    required this.initial,
  });

  final String title;
  final String label;
  final double initial;

  @override
  State<_AmountDialog> createState() => _AmountDialogState();
}

class _AmountDialogState extends State<_AmountDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _controller =
      TextEditingController(text: widget.initial.toStringAsFixed(2));

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.of(context).pop(SettingsController.parseAmount(_controller.text));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: SizedBox(
        width: 360,
        child: Form(
          key: _formKey,
          child: TextFormField(
            controller: _controller,
            autofocus: true,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            onFieldSubmitted: (_) => _save(),
            decoration: InputDecoration(labelText: widget.label, prefixText: r'$ '),
            validator: SettingsController.validateAmount,
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _save, child: const Text('Save')),
      ],
    );
  }
}
