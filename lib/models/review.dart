class Review {
  final String id;
  final String productId;
  final String productName;
  final String customerId;
  final String customerName;
  final int rating;
  final String text;
  final bool deleted;

  const Review({
    required this.id,
    required this.productId,
    this.productName = '',
    required this.customerId,
    this.customerName = '',
    required this.rating,
    required this.text,
    this.deleted = false,
  });

  Map<String, dynamic> toJson() => {
    'product': productId,
    'customer': customerId,
    'rating': rating,
    'text': text,
    'deleted': deleted,
  };

  factory Review.fromJson(Map<String, dynamic> json) {
    final expand = json['expand'] as Map<String, dynamic>? ?? {};
    final product = expand['product'];
    final customer = expand['customer'];
    final productRaw = json['product'];
    final customerRaw = json['customer'];
    return Review(
      id: json['id'] as String? ?? '',
      productId:
          productRaw is String
              ? productRaw
              : (productRaw is Map ? productRaw['id'] as String? ?? '' : ''),
      productName: product is Map ? (product['name'] as String? ?? '') : '',
      customerId:
          customerRaw is String
              ? customerRaw
              : (customerRaw is Map ? customerRaw['id'] as String? ?? '' : ''),
      customerName:
          customer is Map ? (customer['fullName'] as String? ?? '') : '',
      rating: (json['rating'] as num?)?.toInt() ?? 0,
      text: json['text'] as String? ?? '',
      deleted: json['deleted'] as bool? ?? false,
    );
  }
}
