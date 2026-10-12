class Category {
  final String id;
  final String name;
  final String slug;
  final String description;
  final bool deleted;

  const Category({
    required this.id,
    required this.name,
    required this.slug,
    this.description = '',
    this.deleted = false,
  });

  Category copyWith({
    String? name,
    String? slug,
    String? description,
    bool? deleted,
  }) {
    return Category(
      id: id,
      name: name ?? this.name,
      slug: slug ?? this.slug,
      description: description ?? this.description,
      deleted: deleted ?? this.deleted,
    );
  }

  Map<String, dynamic> toJson() => {
    'name': name,
    'slug': slug,
    'description': description,
    'deleted': deleted,
  };

  factory Category.fromJson(Map<String, dynamic> json) => Category(
    id: json['id'] as String? ?? '',
    name: json['name'] as String? ?? '',
    slug: json['slug'] as String? ?? '',
    description: json['description'] as String? ?? '',
    deleted: json['deleted'] as bool? ?? false,
  );
}
