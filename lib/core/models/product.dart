import '../config/app_config.dart';

/// A canteen product with a price and a stock level.
class Product {
  const Product({
    required this.id,
    required this.name,
    required this.price,
    required this.stock,
  });

  final String id;
  final String name;
  final double price;
  final int stock;

  bool get isOutOfStock => stock <= 0;
  bool get isLowStock => !isOutOfStock && stock <= AppConfig.lowStockThreshold;

  Product copyWith({String? name, double? price, int? stock}) => Product(
        id: id,
        name: name ?? this.name,
        price: price ?? this.price,
        stock: stock ?? this.stock,
      );
}
