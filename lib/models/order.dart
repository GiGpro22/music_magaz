enum OrderStatus {
  // Не используем value "new" — в PocketBase filter это зарезервировано.
  newOrder('created', 'Новый'),
  paid('paid', 'Оплачен'),
  shipped('shipped', 'Отправлен'),
  cancelled('cancelled', 'Отменён'),
  completed('completed', 'Завершён');

  const OrderStatus(this.value, this.label);
  final String value;
  final String label;

  static OrderStatus fromString(String? raw) {
    if (raw == 'new') return OrderStatus.newOrder;
    return OrderStatus.values.firstWhere(
      (e) => e.value == raw || e.name == raw,
      orElse: () => OrderStatus.newOrder,
    );
  }
}

class OrderItem {
  final String id;
  final String orderId;
  final String productId;
  final String productName;
  final int qty;
  final double unitPrice;
  final double lineTotal;

  const OrderItem({
    required this.id,
    required this.orderId,
    required this.productId,
    this.productName = '',
    required this.qty,
    required this.unitPrice,
    required this.lineTotal,
  });

  Map<String, dynamic> toJson() => {
    'order': orderId,
    'product': productId,
    'qty': qty,
    'unitPrice': unitPrice,
    'lineTotal': lineTotal,
  };

  factory OrderItem.fromJson(Map<String, dynamic> json) {
    final expand = json['expand'] as Map<String, dynamic>? ?? {};
    final product = expand['product'];
    final productRaw = json['product'];
    final orderRaw = json['order'];
    return OrderItem(
      id: json['id'] as String? ?? '',
      orderId:
          orderRaw is String
              ? orderRaw
              : (orderRaw is Map ? orderRaw['id'] as String? ?? '' : ''),
      productId:
          productRaw is String
              ? productRaw
              : (productRaw is Map ? productRaw['id'] as String? ?? '' : ''),
      productName: product is Map ? (product['name'] as String? ?? '') : '',
      qty: (json['qty'] as num?)?.toInt() ?? 0,
      unitPrice: (json['unitPrice'] as num?)?.toDouble() ?? 0,
      lineTotal: (json['lineTotal'] as num?)?.toDouble() ?? 0,
    );
  }
}

class ShopOrder {
  final String id;
  final String customerId;
  final String customerName;
  final OrderStatus status;
  final double subtotal;
  final double loyaltyDiscount;
  final double promoDiscount;
  final double total;
  final String note;
  final bool deleted;
  final DateTime? created;
  final List<OrderItem> items;

  const ShopOrder({
    required this.id,
    required this.customerId,
    this.customerName = '',
    required this.status,
    required this.subtotal,
    this.loyaltyDiscount = 0,
    this.promoDiscount = 0,
    required this.total,
    this.note = '',
    this.deleted = false,
    this.created,
    this.items = const [],
  });

  Map<String, dynamic> toJson() => {
    'customer': customerId,
    'status': status.value,
    'subtotal': subtotal,
    'loyaltyDiscount': loyaltyDiscount,
    'promoDiscount': promoDiscount,
    'total': total,
    'note': note,
    'deleted': deleted,
  };

  factory ShopOrder.fromJson(Map<String, dynamic> json) {
    final expand = json['expand'] as Map<String, dynamic>? ?? {};
    final customer = expand['customer'];
    final customerRaw = json['customer'];
    return ShopOrder(
      id: json['id'] as String? ?? '',
      customerId:
          customerRaw is String
              ? customerRaw
              : (customerRaw is Map ? customerRaw['id'] as String? ?? '' : ''),
      customerName:
          customer is Map ? (customer['fullName'] as String? ?? '') : '',
      status: OrderStatus.fromString(json['status'] as String?),
      subtotal: (json['subtotal'] as num?)?.toDouble() ?? 0,
      loyaltyDiscount: (json['loyaltyDiscount'] as num?)?.toDouble() ?? 0,
      promoDiscount: (json['promoDiscount'] as num?)?.toDouble() ?? 0,
      total: (json['total'] as num?)?.toDouble() ?? 0,
      note: json['note'] as String? ?? '',
      deleted: json['deleted'] as bool? ?? false,
      created: DateTime.tryParse(json['created'] as String? ?? ''),
    );
  }

  ShopOrder copyWith({
    OrderStatus? status,
    bool? deleted,
    List<OrderItem>? items,
  }) {
    return ShopOrder(
      id: id,
      customerId: customerId,
      customerName: customerName,
      status: status ?? this.status,
      subtotal: subtotal,
      loyaltyDiscount: loyaltyDiscount,
      promoDiscount: promoDiscount,
      total: total,
      note: note,
      deleted: deleted ?? this.deleted,
      created: created,
      items: items ?? this.items,
    );
  }
}
