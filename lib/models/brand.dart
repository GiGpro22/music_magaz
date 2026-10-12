class Brand {
  final String id;
  final String name;
  final String country;
  final String website;
  final String description;
  final bool deleted;

  const Brand({
    required this.id,
    required this.name,
    required this.country,
    this.website = '',
    this.description = '',
    this.deleted = false,
  });

  Brand copyWith({
    String? name,
    String? country,
    String? website,
    String? description,
    bool? deleted,
  }) {
    return Brand(
      id: id,
      name: name ?? this.name,
      country: country ?? this.country,
      website: website ?? this.website,
      description: description ?? this.description,
      deleted: deleted ?? this.deleted,
    );
  }

  Map<String, dynamic> toJson() => {
    'name': name,
    'country': country,
    'website': website,
    'description': description,
    'deleted': deleted,
  };

  factory Brand.fromJson(Map<String, dynamic> json) => Brand(
    id: json['id'] as String? ?? '',
    name: json['name'] as String? ?? '',
    country: json['country'] as String? ?? '',
    website: json['website'] as String? ?? '',
    description: json['description'] as String? ?? '',
    deleted: json['deleted'] as bool? ?? false,
  );
}
