class Supplier {
  final String id;
  final String name;
  final String email;
  final String phone;
  final String city;
  final bool deleted;

  const Supplier({
    required this.id,
    required this.name,
    required this.email,
    this.phone = '',
    required this.city,
    this.deleted = false,
  });

  Supplier copyWith({
    String? name,
    String? email,
    String? phone,
    String? city,
    bool? deleted,
  }) {
    return Supplier(
      id: id,
      name: name ?? this.name,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      city: city ?? this.city,
      deleted: deleted ?? this.deleted,
    );
  }

  Map<String, dynamic> toJson() => {
    'name': name,
    'email': email,
    'phone': phone,
    'city': city,
    'deleted': deleted,
  };

  factory Supplier.fromJson(Map<String, dynamic> json) => Supplier(
    id: json['id'] as String? ?? '',
    name: json['name'] as String? ?? '',
    email: json['email'] as String? ?? '',
    phone: json['phone'] as String? ?? '',
    city: json['city'] as String? ?? '',
    deleted: json['deleted'] as bool? ?? false,
  );
}
