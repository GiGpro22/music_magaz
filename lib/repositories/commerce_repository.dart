import 'package:dio/dio.dart';

import '../core/api_exceptions.dart';
import '../models/customer.dart';
import '../models/list_query.dart';
import '../models/order.dart';
import '../models/page_result.dart';
import '../models/promotion.dart';
import '../models/review.dart';
import 'pb_helpers.dart';

abstract interface class CustomerRepository {
  Future<PageResult<Customer>> find(
    ListQuery query, {
    CancelToken? cancelToken,
  });
  Future<List<Customer>> findAllActive();
  Future<Customer?> findById(String id);
  Future<Customer> create(Customer customer);
  Future<Customer> update(Customer customer);
  Future<void> softDelete(String id);
  Future<void> hardDelete(String id);
  Future<void> restore(String id);
  Future<int> deleteMany(List<String> ids);
}

abstract interface class LoyaltyCardRepository {
  Future<LoyaltyCard?> findByCustomerId(String customerId);
  Future<LoyaltyCard> create(LoyaltyCard card);
  Future<LoyaltyCard> update(LoyaltyCard card);
}

abstract interface class PromotionRepository {
  Future<PageResult<Promotion>> find(
    ListQuery query, {
    CancelToken? cancelToken,
  });
  Future<List<Promotion>> findActive();
  Future<Promotion?> findById(String id);
  Future<Promotion> create(Promotion promo);
  Future<Promotion> update(Promotion promo);
  Future<void> softDelete(String id);
  Future<void> hardDelete(String id);
  Future<void> restore(String id);
  Future<int> deleteMany(List<String> ids);
}

abstract interface class OrderRepository {
  Future<PageResult<ShopOrder>> find(
    ListQuery query, {
    CancelToken? cancelToken,
  });
  Future<ShopOrder?> findById(String id);
  Future<ShopOrder> create(ShopOrder order, List<OrderItem> items);
  Future<ShopOrder> updateStatus(String id, OrderStatus status);
  Future<void> softDelete(String id);
  Future<void> hardDelete(String id);
  Future<void> restore(String id);
  Future<List<OrderItem>> itemsOf(String orderId);
}

abstract interface class ReviewRepository {
  Future<PageResult<Review>> find(ListQuery query, {CancelToken? cancelToken});
  Future<Review> create(Review review);
  Future<void> softDelete(String id);
  Future<void> hardDelete(String id);
  Future<void> restore(String id);
  Future<int> deleteMany(List<String> ids);
}

class PbCustomerRepository implements CustomerRepository {
  PbCustomerRepository(this._dio);
  final Dio _dio;
  List<Customer>? _cache;

  @override
  Future<PageResult<Customer>> find(
    ListQuery query, {
    CancelToken? cancelToken,
  }) => pbList(
    dio: _dio,
    collection: 'customers',
    query: query,
    fromJson: Customer.fromJson,
    searchFields: 'fullName,email,city',
    cancelToken: cancelToken,
  );

  @override
  Future<List<Customer>> findAllActive() async {
    if (_cache != null) return _cache!;
    final page = await find(const ListQuery(size: 200, sortField: 'fullName'));
    _cache = page.items.where((e) => !e.deleted).toList();
    return _cache!;
  }

  void _invalidate() => _cache = null;

  @override
  Future<Customer?> findById(String id) async {
    try {
      return await pbGet(
        dio: _dio,
        collection: 'customers',
        id: id,
        fromJson: Customer.fromJson,
      );
    } on NotFoundException {
      return null;
    }
  }

  @override
  Future<Customer> create(Customer customer) async {
    _invalidate();
    return pbCreate(
      dio: _dio,
      collection: 'customers',
      body: customer.toJson(),
      fromJson: Customer.fromJson,
    );
  }

  @override
  Future<Customer> update(Customer customer) async {
    _invalidate();
    return pbUpdate(
      dio: _dio,
      collection: 'customers',
      id: customer.id,
      body: customer.toJson(),
      fromJson: Customer.fromJson,
    );
  }

  @override
  Future<void> softDelete(String id) async {
    _invalidate();
    await pbUpdate(
      dio: _dio,
      collection: 'customers',
      id: id,
      body: {'deleted': true},
      fromJson: Customer.fromJson,
    );
  }

  @override
  Future<void> hardDelete(String id) async {
    _invalidate();
    await pbDelete(dio: _dio, collection: 'customers', id: id);
  }

  @override
  Future<void> restore(String id) async {
    _invalidate();
    await pbUpdate(
      dio: _dio,
      collection: 'customers',
      id: id,
      body: {'deleted': false},
      fromJson: Customer.fromJson,
    );
  }

  @override
  Future<int> deleteMany(List<String> ids) async {
    var count = 0;
    for (final id in ids) {
      await softDelete(id);
      count++;
    }
    return count;
  }
}

class PbLoyaltyCardRepository implements LoyaltyCardRepository {
  PbLoyaltyCardRepository(this._dio);
  final Dio _dio;

  @override
  Future<LoyaltyCard?> findByCustomerId(String customerId) async {
    return guard(() async {
      final response = await _dio.get(
        '/api/collections/loyalty_cards/records',
        queryParameters: {
          'page': 1,
          'perPage': 1,
          'filter': 'customer="${escapeFilter(customerId)}" && deleted=false',
        },
      );
      final items = (response.data as Map)['items'] as List? ?? [];
      if (items.isEmpty) return null;
      return LoyaltyCard.fromJson(
        Map<String, dynamic>.from(items.first as Map),
      );
    });
  }

  @override
  Future<LoyaltyCard> create(LoyaltyCard card) => pbCreate(
    dio: _dio,
    collection: 'loyalty_cards',
    body: card.toJson(),
    fromJson: LoyaltyCard.fromJson,
  );

  @override
  Future<LoyaltyCard> update(LoyaltyCard card) => pbUpdate(
    dio: _dio,
    collection: 'loyalty_cards',
    id: card.id,
    body: card.toJson(),
    fromJson: LoyaltyCard.fromJson,
  );
}

class PbPromotionRepository implements PromotionRepository {
  PbPromotionRepository(this._dio);
  final Dio _dio;

  @override
  Future<PageResult<Promotion>> find(
    ListQuery query, {
    CancelToken? cancelToken,
  }) => pbList(
    dio: _dio,
    collection: 'promotions',
    query: query,
    fromJson: Promotion.fromJson,
    searchFields: 'title',
    expand: 'brand,categories',
    cancelToken: cancelToken,
  );

  @override
  Future<List<Promotion>> findActive() async {
    final page = await find(const ListQuery(size: 100, sortField: 'title'));
    final now = DateTime.now();
    return page.items.where((p) => p.isEffectiveOn(now)).toList();
  }

  @override
  Future<Promotion?> findById(String id) async {
    try {
      return await pbGet(
        dio: _dio,
        collection: 'promotions',
        id: id,
        fromJson: Promotion.fromJson,
        expand: 'brand,categories',
      );
    } on NotFoundException {
      return null;
    }
  }

  @override
  Future<Promotion> create(Promotion promo) => pbCreate(
    dio: _dio,
    collection: 'promotions',
    body: promo.toJson(),
    fromJson: Promotion.fromJson,
    expand: 'brand,categories',
  );

  @override
  Future<Promotion> update(Promotion promo) => pbUpdate(
    dio: _dio,
    collection: 'promotions',
    id: promo.id,
    body: promo.toJson(),
    fromJson: Promotion.fromJson,
    expand: 'brand,categories',
  );

  @override
  Future<void> softDelete(String id) => pbUpdate(
    dio: _dio,
    collection: 'promotions',
    id: id,
    body: {'deleted': true},
    fromJson: Promotion.fromJson,
  );

  @override
  Future<void> hardDelete(String id) =>
      pbDelete(dio: _dio, collection: 'promotions', id: id);

  @override
  Future<void> restore(String id) => pbUpdate(
    dio: _dio,
    collection: 'promotions',
    id: id,
    body: {'deleted': false},
    fromJson: Promotion.fromJson,
  );

  @override
  Future<int> deleteMany(List<String> ids) async {
    var count = 0;
    for (final id in ids) {
      await softDelete(id);
      count++;
    }
    return count;
  }
}

class PbOrderRepository implements OrderRepository {
  PbOrderRepository(this._dio);
  final Dio _dio;

  @override
  Future<PageResult<ShopOrder>> find(
    ListQuery query, {
    CancelToken? cancelToken,
  }) => pbList(
    dio: _dio,
    collection: 'orders',
    query: query.copyWith(
      sortField:
          (query.sortField == 'name' || query.sortField.isEmpty)
              ? 'created'
              : query.sortField,
    ),
    fromJson: ShopOrder.fromJson,
    searchFields: 'note',
    expand: 'customer',
    cancelToken: cancelToken,
  );

  @override
  Future<ShopOrder?> findById(String id) async {
    try {
      final order = await pbGet(
        dio: _dio,
        collection: 'orders',
        id: id,
        fromJson: ShopOrder.fromJson,
        expand: 'customer',
      );
      final items = await itemsOf(id);
      return order.copyWith(items: items);
    } on NotFoundException {
      return null;
    }
  }

  @override
  Future<List<OrderItem>> itemsOf(String orderId) async {
    return guard(() async {
      final response = await _dio.get(
        '/api/collections/order_items/records',
        queryParameters: {
          'page': 1,
          'perPage': 200,
          'filter': 'order="${escapeFilter(orderId)}"',
          'expand': 'product',
        },
      );
      final items = (response.data as Map)['items'] as List? ?? [];
      return items
          .whereType<Map>()
          .map((e) => OrderItem.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    });
  }

  @override
  Future<ShopOrder> create(ShopOrder order, List<OrderItem> items) async {
    return guard(() async {
      final created = await pbCreate(
        dio: _dio,
        collection: 'orders',
        body: order.toJson(),
        fromJson: ShopOrder.fromJson,
      );
      final savedItems = <OrderItem>[];
      for (final item in items) {
        final body = <String, dynamic>{
          'order': created.id,
          'product': item.productId,
          'qty': item.qty,
          'unitPrice': item.unitPrice,
          'lineTotal': item.lineTotal,
        };
        final saved = await pbCreate(
          dio: _dio,
          collection: 'order_items',
          body: body,
          fromJson: OrderItem.fromJson,
        );
        savedItems.add(saved);
      }
      return created.copyWith(items: savedItems);
    });
  }

  @override
  Future<ShopOrder> updateStatus(String id, OrderStatus status) => pbUpdate(
    dio: _dio,
    collection: 'orders',
    id: id,
    body: {'status': status.value},
    fromJson: ShopOrder.fromJson,
    expand: 'customer',
  );

  @override
  Future<void> softDelete(String id) => pbUpdate(
    dio: _dio,
    collection: 'orders',
    id: id,
    body: {'deleted': true},
    fromJson: ShopOrder.fromJson,
  );

  @override
  Future<void> hardDelete(String id) =>
      pbDelete(dio: _dio, collection: 'orders', id: id);

  @override
  Future<void> restore(String id) => pbUpdate(
    dio: _dio,
    collection: 'orders',
    id: id,
    body: {'deleted': false},
    fromJson: ShopOrder.fromJson,
  );
}

class PbReviewRepository implements ReviewRepository {
  PbReviewRepository(this._dio);
  final Dio _dio;

  @override
  Future<PageResult<Review>> find(
    ListQuery query, {
    CancelToken? cancelToken,
  }) => pbList(
    dio: _dio,
    collection: 'reviews',
    query: query.copyWith(
      sortField: query.sortField == 'name' ? 'rating' : query.sortField,
    ),
    fromJson: Review.fromJson,
    searchFields: 'text',
    expand: 'product,customer',
    cancelToken: cancelToken,
  );

  @override
  Future<Review> create(Review review) => pbCreate(
    dio: _dio,
    collection: 'reviews',
    body: review.toJson(),
    fromJson: Review.fromJson,
    expand: 'product,customer',
  );

  @override
  Future<void> softDelete(String id) => pbUpdate(
    dio: _dio,
    collection: 'reviews',
    id: id,
    body: {'deleted': true},
    fromJson: Review.fromJson,
  );

  @override
  Future<void> hardDelete(String id) =>
      pbDelete(dio: _dio, collection: 'reviews', id: id);

  @override
  Future<void> restore(String id) => pbUpdate(
    dio: _dio,
    collection: 'reviews',
    id: id,
    body: {'deleted': false},
    fromJson: Review.fromJson,
  );

  @override
  Future<int> deleteMany(List<String> ids) async {
    var count = 0;
    for (final id in ids) {
      await softDelete(id);
      count++;
    }
    return count;
  }
}
