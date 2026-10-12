import '../models/customer.dart';
import '../models/product.dart';
import '../models/promotion.dart';

class CartLine {
  final Product product;
  final int qty;

  const CartLine({required this.product, required this.qty});

  double get lineTotal => product.price * qty;
}

class PricingResult {
  final double subtotal;
  final double loyaltyDiscount;
  final double promoDiscount;
  final double total;
  final List<String> appliedPromos;

  const PricingResult({
    required this.subtotal,
    required this.loyaltyDiscount,
    required this.promoDiscount,
    required this.total,
    this.appliedPromos = const [],
  });
}

/// Содержательная особенность предметной области: расчёт стоимости заказа.
class OrderPricingService {
  PricingResult calculate({
    required List<CartLine> lines,
    LoyaltyCard? loyaltyCard,
    List<Promotion> promotions = const [],
    DateTime? now,
  }) {
    if (lines.isEmpty) {
      return const PricingResult(
        subtotal: 0,
        loyaltyDiscount: 0,
        promoDiscount: 0,
        total: 0,
      );
    }

    final moment = now ?? DateTime.now();
    final subtotal = lines.fold<double>(0, (sum, l) => sum + l.lineTotal);

    final loyaltyRate =
        (loyaltyCard != null && loyaltyCard.isActive && !loyaltyCard.deleted)
            ? loyaltyCard.level.discountRate
            : 0.0;
    final loyaltyDiscount = _round(subtotal * loyaltyRate);

    var promoDiscount = 0.0;
    final applied = <String>[];
    final active = promotions.where((p) => p.isEffectiveOn(moment)).toList();

    for (final line in lines) {
      double bestRate = 0;
      Promotion? bestPromo;
      for (final promo in active) {
        final matchesBrand =
            promo.brandId == null || promo.brandId == line.product.brandId;
        final matchesCategory =
            promo.categoryIds.isEmpty ||
            line.product.categoryIds.any(
              (id) => promo.categoryIds.contains(id),
            );
        if (matchesBrand && matchesCategory) {
          final rate = promo.discountPercent / 100.0;
          if (rate > bestRate) {
            bestRate = rate;
            bestPromo = promo;
          }
        }
      }
      if (bestPromo != null && bestRate > 0) {
        promoDiscount += line.lineTotal * bestRate;
        if (!applied.contains(bestPromo.title)) {
          applied.add(bestPromo.title);
        }
      }
    }
    promoDiscount = _round(promoDiscount);

    final total =
        (subtotal - loyaltyDiscount - promoDiscount)
            .clamp(0, double.infinity)
            .toDouble();

    return PricingResult(
      subtotal: _round(subtotal),
      loyaltyDiscount: loyaltyDiscount,
      promoDiscount: promoDiscount,
      total: _round(total),
      appliedPromos: applied,
    );
  }

  double _round(double value) => (value * 100).roundToDouble() / 100;
}
