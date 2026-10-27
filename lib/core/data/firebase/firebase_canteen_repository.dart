import 'package:cloud_firestore/cloud_firestore.dart';

import '../../models/product.dart';
import '../../models/sale.dart';
import '../../repositories/repositories.dart';

/// Products in `products/{id}` and sales in `sales/{id}`.
class FirebaseCanteenRepository implements CanteenRepository {
  FirebaseCanteenRepository({FirebaseFirestore? firestore})
      : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _products =>
      _db.collection('products');
  CollectionReference<Map<String, dynamic>> get _sales => _db.collection('sales');

  Product _productFromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    return Product(
      id: doc.id,
      name: (data['name'] as String?) ?? '',
      price: ((data['price'] as num?) ?? 0).toDouble(),
      stock: (data['stock'] as num?)?.toInt() ?? 0,
    );
  }

  Sale _saleFromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    final rawLines = (data['lines'] as List<dynamic>?) ?? const [];
    return Sale(
      id: doc.id,
      soldAt: (data['soldAt'] as Timestamp).toDate(),
      voided: (data['voided'] as bool?) ?? false,
      soldBy: data['soldBy'] as String?,
      lines: [
        for (final raw in rawLines.cast<Map<String, dynamic>>())
          SaleLine(
            productId: (raw['productId'] as String?) ?? '',
            productName: (raw['productName'] as String?) ?? '',
            unitPrice: ((raw['unitPrice'] as num?) ?? 0).toDouble(),
            quantity: (raw['quantity'] as num?)?.toInt() ?? 0,
          ),
      ],
    );
  }

  @override
  Stream<List<Product>> watchProducts() {
    return _products.snapshots().map((snapshot) {
      final list = snapshot.docs.map(_productFromDoc).toList()
        ..sort((a, b) => a.name.compareTo(b.name));
      return list;
    });
  }

  @override
  Stream<List<Sale>> watchSales(DateTime from, DateTime to) {
    return _sales
        .where('soldAt', isGreaterThanOrEqualTo: Timestamp.fromDate(from))
        .where('soldAt', isLessThan: Timestamp.fromDate(to))
        .snapshots()
        .map((snapshot) {
      final list = snapshot.docs.map(_saleFromDoc).toList()
        ..sort((a, b) => b.soldAt.compareTo(a.soldAt));
      return list;
    });
  }

  @override
  Future<Product> addProduct({
    required String name,
    required double price,
    required int stock,
  }) async {
    final ref = _products.doc();
    await ref.set({
      'name': name,
      'price': price,
      'stock': stock,
      'createdAt': FieldValue.serverTimestamp(),
    });
    return Product(id: ref.id, name: name, price: price, stock: stock);
  }

  @override
  Future<void> updateProduct(Product product) {
    return _products.doc(product.id).update({
      'name': product.name,
      'price': product.price,
      'stock': product.stock,
    });
  }

  @override
  Future<void> deleteProduct(String id) => _products.doc(id).delete();

  @override
  Future<Sale> checkout(List<CartItem> items, {String? soldBy}) async {
    final saleRef = _sales.doc();
    final soldAt = DateTime.now();
    final lines = [
      for (final item in items)
        SaleLine(
          productId: item.product.id,
          productName: item.product.name,
          unitPrice: item.product.price,
          quantity: item.quantity,
        ),
    ];
    await _db.runTransaction((tx) async {
      // All reads must happen before any write.
      final stocks = <String, int>{};
      for (final item in items) {
        final doc = await tx.get(_products.doc(item.product.id));
        final stock = (doc.data()?['stock'] as num?)?.toInt() ?? 0;
        if (!doc.exists || stock < item.quantity) {
          throw InsufficientStockException(item.product.name);
        }
        stocks[item.product.id] = stock;
      }
      for (final item in items) {
        tx.update(_products.doc(item.product.id),
            {'stock': stocks[item.product.id]! - item.quantity});
      }
      tx.set(saleRef, {
        'soldAt': Timestamp.fromDate(soldAt),
        'soldBy': soldBy,
        'voided': false,
        'lines': [
          for (final line in lines)
            {
              'productId': line.productId,
              'productName': line.productName,
              'unitPrice': line.unitPrice,
              'quantity': line.quantity,
            },
        ],
      });
    });
    return Sale(id: saleRef.id, soldAt: soldAt, lines: lines, soldBy: soldBy);
  }

  @override
  Future<void> voidSale(Sale sale) async {
    final saleRef = _sales.doc(sale.id);
    await _db.runTransaction((tx) async {
      final saleDoc = await tx.get(saleRef);
      if (!saleDoc.exists || (saleDoc.data()?['voided'] as bool? ?? false)) return;
      final stocks = <String, int>{};
      for (final line in sale.lines) {
        final doc = await tx.get(_products.doc(line.productId));
        if (doc.exists) stocks[line.productId] = (doc.data()?['stock'] as num?)?.toInt() ?? 0;
      }
      for (final line in sale.lines) {
        final current = stocks[line.productId];
        if (current != null) {
          tx.update(_products.doc(line.productId), {'stock': current + line.quantity});
        }
      }
      tx.update(saleRef, {'voided': true});
    });
  }
}
