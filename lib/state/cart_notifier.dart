import 'package:flutter/foundation.dart';

import '../core/api_exceptions.dart';
import '../models/order.dart';
import '../models/product.dart';
import '../models/promotion.dart';
import '../repositories/catalog_repository.dart';
import '../repositories/commerce_repository.dart';
import 'order_pricing.dart';

class CartNotifier extends ChangeNotifier {
  CartNotifier({
    required ProductRepository products,
    required OrderRepository orders,
    required LoyaltyCardRepository loyaltyCards,
    required PromotionRepository promotions,
  }) : _products = products,
       _orders = orders,
       _loyaltyCards = loyaltyCards,
       _promotions = promotions;

  final ProductRepository _products;
  final OrderRepository _orders;
  final LoyaltyCardRepository _loyaltyCards;
  final PromotionRepository _promotions;
  final OrderPricingService _pricing = OrderPricingService();

  final Map<String, CartLine> _lines = {};
  bool _placing = false;
  bool _disposed = false;

  List<CartLine> get lines => _lines.values.toList();
  bool get isEmpty => _lines.isEmpty;
  bool get placing => _placing;
  int get totalQty => _lines.values.fold(0, (s, l) => s + l.qty);

  void add(Product product, {int qty = 1}) {
    final existing = _lines[product.id];
    final nextQty = (existing?.qty ?? 0) + qty;
    if (nextQty > product.stock) {
      throw ConflictException(
        'На складе только ${product.stock} шт. «${product.name}»',
      );
    }
    _lines[product.id] = CartLine(product: product, qty: nextQty);
    _safeNotify();
  }

  void setQty(String productId, int qty) {
    final line = _lines[productId];
    if (line == null) return;
    if (qty <= 0) {
      _lines.remove(productId);
    } else {
      if (qty > line.product.stock) {
        throw ConflictException('На складе только ${line.product.stock} шт.');
      }
      _lines[productId] = CartLine(product: line.product, qty: qty);
    }
    _safeNotify();
  }

  void remove(String productId) {
    _lines.remove(productId);
    _safeNotify();
  }

  void clear() {
    _lines.clear();
    _safeNotify();
  }

  Future<List<Promotion>> _safePromos() async {
    try {
      return await _promotions.findActive();
    } on ApiException {
      return const [];
    }
  }

  Future<PricingResult> preview(String customerId) async {
    final card = await _loyaltyCards.findByCustomerId(customerId);
    final promos = await _safePromos();
    return _pricing.calculate(
      lines: lines,
      loyaltyCard: card,
      promotions: promos,
    );
  }

  Future<ShopOrder> checkout({
    required String customerId,
    String note = '',
  }) async {
    if (_lines.isEmpty) {
      throw const ConflictException('Корзина пуста');
    }
    _placing = true;
    _safeNotify();
    try {
      final card = await _loyaltyCards.findByCustomerId(customerId);
      final promos = await _safePromos();
      final pricing = _pricing.calculate(
        lines: lines,
        loyaltyCard: card,
        promotions: promos,
      );

      for (final line in lines) {
        final fresh = await _products.findById(line.product.id);
        if (fresh == null || fresh.deleted) {
          throw ConflictException('Товар «${line.product.name}» недоступен');
        }
        if (fresh.stock < line.qty) {
          throw ConflictException(
            'Недостаточно остатков «${fresh.name}»: ${fresh.stock} шт.',
          );
        }
      }

      final order = ShopOrder(
        id: '',
        customerId: customerId,
        status: OrderStatus.newOrder,
        subtotal: pricing.subtotal,
        loyaltyDiscount: pricing.loyaltyDiscount,
        promoDiscount: pricing.promoDiscount,
        total: pricing.total,
        note: note,
      );

      final items =
          lines
              .map(
                (l) => OrderItem(
                  id: '',
                  orderId: '',
                  productId: l.product.id,
                  productName: l.product.name,
                  qty: l.qty,
                  unitPrice: l.product.price,
                  lineTotal: l.lineTotal,
                ),
              )
              .toList();

      final created = await _orders.create(order, items);
      for (final line in lines) {
        try {
          await _products.decreaseStock(line.product.id, line.qty);
        } on ApiException {
          // Заказ уже создан; остаток обновит продавец при необходимости.
        }
      }
      clear();
      return created;
    } finally {
      _placing = false;
      _safeNotify();
    }
  }

  void _safeNotify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
