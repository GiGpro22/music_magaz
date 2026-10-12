import 'package:flutter_test/flutter_test.dart';
import 'package:music_magaz/core/validators.dart';
import 'package:music_magaz/models/customer.dart';
import 'package:music_magaz/models/product.dart';
import 'package:music_magaz/models/promotion.dart';
import 'package:music_magaz/models/role.dart';
import 'package:music_magaz/state/order_pricing.dart';

void main() {
  group('Валидаторы', () {
    test('пустая строка отклоняется', () {
      expect(V.required()(''), isNotNull);
      expect(V.required()('   '), isNotNull);
    });

    test('непустая строка принимается', () {
      expect(V.required()('Fender'), isNull);
    });

    test('email проверяется', () {
      expect(V.email()('bad'), isNotNull);
      expect(V.email()('a@b.ru'), isNull);
    });

    test('пароль требует цифру и спецсимвол', () {
      expect(V.password()('abcdefg1'), isNotNull);
      expect(V.password()('abcdefg!'), isNotNull);
      expect(V.password()('abcdefg1!'), isNull);
    });
  });

  group('Разбор модели Product', () {
    test('отсутствующие поля не приводят к исключению', () {
      final p = Product.fromJson({'id': '1'});
      expect(p.name, '');
      expect(p.categoryIds, isEmpty);
      expect(p.price, 0);
    });

    test('expand разбирает бренд и категории', () {
      final p = Product.fromJson({
        'id': '1',
        'name': 'Strat',
        'sku': 'S1',
        'price': 100,
        'stock': 2,
        'brand': 'b1',
        'supplier': 's1',
        'categories': ['c1'],
        'expand': {
          'brand': {'id': 'b1', 'name': 'Fender'},
          'supplier': {'id': 's1', 'name': 'Trade'},
          'categories': [
            {'id': 'c1', 'name': 'Гитары'},
          ],
        },
      });
      expect(p.brandName, 'Fender');
      expect(p.categoryNames, ['Гитары']);
    });
  });

  group('Права RBAC', () {
    test('покупатель не управляет каталогом', () {
      expect(Permissions.canManageCatalog(Role.customer), isFalse);
      expect(Permissions.canViewMyOrders(Role.customer), isTrue);
    });

    test('продавец обрабатывает заказы, но не отчёты', () {
      expect(Permissions.canProcessOrders(Role.seller), isTrue);
      expect(Permissions.canViewReports(Role.seller), isFalse);
    });

    test('админ имеет hard-delete и пользователей', () {
      expect(Permissions.canHardDelete(Role.admin), isTrue);
      expect(Permissions.canManageUsers(Role.admin), isTrue);
    });
  });

  group('OrderPricingService', () {
    final service = OrderPricingService();
    final product = Product(
      id: 'p1',
      name: 'Strat',
      sku: 'S1',
      price: 1000,
      stock: 5,
      brandId: 'b1',
      supplierId: 's1',
      categoryIds: ['c1'],
    );

    test('пустая корзина даёт ноль', () {
      final r = service.calculate(lines: []);
      expect(r.total, 0);
    });

    test('скидка золотой карты 12%', () {
      final card = LoyaltyCard(
        id: 'l1',
        customerId: 'c1',
        cardNumber: 'MC-1',
        level: LoyaltyLevel.gold,
        issuedAt: DateTime(2024),
      );
      final r = service.calculate(
        lines: [CartLine(product: product, qty: 2)],
        loyaltyCard: card,
      );
      expect(r.subtotal, 2000);
      expect(r.loyaltyDiscount, 240);
      expect(r.total, 1760);
    });

    test('акция на бренд применяется к позиции', () {
      final promo = Promotion(
        id: 'pr1',
        title: 'Fender -10%',
        discountPercent: 10,
        brandId: 'b1',
        startsAt: DateTime(2020),
        endsAt: DateTime(2099),
      );
      final r = service.calculate(
        lines: [CartLine(product: product, qty: 1)],
        promotions: [promo],
      );
      expect(r.promoDiscount, 100);
      expect(r.total, 900);
      expect(r.appliedPromos, contains('Fender -10%'));
    });
  });
}
