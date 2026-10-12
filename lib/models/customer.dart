class Customer {
  final String id;
  final String fullName;
  final String email;
  final String phone;
  final String city;
  final bool deleted;

  const Customer({
    required this.id,
    required this.fullName,
    required this.email,
    this.phone = '',
    this.city = '',
    this.deleted = false,
  });

  Customer copyWith({
    String? fullName,
    String? email,
    String? phone,
    String? city,
    bool? deleted,
  }) {
    return Customer(
      id: id,
      fullName: fullName ?? this.fullName,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      city: city ?? this.city,
      deleted: deleted ?? this.deleted,
    );
  }

  Map<String, dynamic> toJson() => {
    'fullName': fullName,
    'email': email,
    'phone': phone,
    'city': city,
    'deleted': deleted,
  };

  factory Customer.fromJson(Map<String, dynamic> json) => Customer(
    id: json['id'] as String? ?? '',
    fullName: json['fullName'] as String? ?? '',
    email: json['email'] as String? ?? '',
    phone: json['phone'] as String? ?? '',
    city: json['city'] as String? ?? '',
    deleted: json['deleted'] as bool? ?? false,
  );
}

enum LoyaltyLevel {
  bronze(0.03, 'Бронза'),
  silver(0.07, 'Серебро'),
  gold(0.12, 'Золото');

  const LoyaltyLevel(this.discountRate, this.label);
  final double discountRate;
  final String label;

  static LoyaltyLevel fromString(String? raw) {
    return LoyaltyLevel.values.firstWhere(
      (e) => e.name == raw,
      orElse: () => LoyaltyLevel.bronze,
    );
  }
}

class LoyaltyCard {
  final String id;
  final String customerId;
  final String cardNumber;
  final LoyaltyLevel level;
  final int points;
  final bool isActive;
  final DateTime issuedAt;
  final bool deleted;

  const LoyaltyCard({
    required this.id,
    required this.customerId,
    required this.cardNumber,
    required this.level,
    this.points = 0,
    this.isActive = true,
    required this.issuedAt,
    this.deleted = false,
  });

  LoyaltyCard copyWith({
    String? cardNumber,
    LoyaltyLevel? level,
    int? points,
    bool? isActive,
    DateTime? issuedAt,
    bool? deleted,
  }) {
    return LoyaltyCard(
      id: id,
      customerId: customerId,
      cardNumber: cardNumber ?? this.cardNumber,
      level: level ?? this.level,
      points: points ?? this.points,
      isActive: isActive ?? this.isActive,
      issuedAt: issuedAt ?? this.issuedAt,
      deleted: deleted ?? this.deleted,
    );
  }

  Map<String, dynamic> toJson() => {
    'customer': customerId,
    'cardNumber': cardNumber,
    'level': level.name,
    'points': points,
    'isActive': isActive,
    'issuedAt': issuedAt.toIso8601String(),
    'deleted': deleted,
  };

  factory LoyaltyCard.fromJson(Map<String, dynamic> json) {
    final customer = json['customer'];
    return LoyaltyCard(
      id: json['id'] as String? ?? '',
      customerId:
          customer is String
              ? customer
              : (customer is Map ? customer['id'] as String? ?? '' : ''),
      cardNumber: json['cardNumber'] as String? ?? '',
      level: LoyaltyLevel.fromString(json['level'] as String?),
      points: (json['points'] as num?)?.toInt() ?? 0,
      isActive: json['isActive'] as bool? ?? true,
      issuedAt:
          DateTime.tryParse(json['issuedAt'] as String? ?? '') ??
          DateTime.now(),
      deleted: json['deleted'] as bool? ?? false,
    );
  }
}
