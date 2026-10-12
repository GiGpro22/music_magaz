class Promotion {
  final String id;
  final String title;
  final double discountPercent;
  final String? brandId;
  final String brandName;
  final List<String> categoryIds;
  final List<String> categoryNames;
  final DateTime startsAt;
  final DateTime endsAt;
  final bool isActive;
  final bool deleted;

  const Promotion({
    required this.id,
    required this.title,
    required this.discountPercent,
    this.brandId,
    this.brandName = '',
    this.categoryIds = const [],
    this.categoryNames = const [],
    required this.startsAt,
    required this.endsAt,
    this.isActive = true,
    this.deleted = false,
  });

  bool isEffectiveOn(DateTime now) {
    if (!isActive || deleted) return false;
    return !now.isBefore(startsAt) && !now.isAfter(endsAt);
  }

  Map<String, dynamic> toJson() => {
    'title': title,
    'discountPercent': discountPercent,
    if (brandId != null) 'brand': brandId,
    'categories': categoryIds,
    'startsAt': startsAt.toIso8601String(),
    'endsAt': endsAt.toIso8601String(),
    'isActive': isActive,
    'deleted': deleted,
  };

  factory Promotion.fromJson(Map<String, dynamic> json) {
    final expand = json['expand'] as Map<String, dynamic>? ?? {};
    final brand = expand['brand'];
    final cats = expand['categories'];
    final brandRaw = json['brand'];
    return Promotion(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      discountPercent: (json['discountPercent'] as num?)?.toDouble() ?? 0,
      brandId:
          brandRaw is String
              ? brandRaw
              : (brandRaw is Map ? brandRaw['id'] as String? : null),
      brandName: brand is Map ? (brand['name'] as String? ?? '') : '',
      categoryIds:
          json['categories'] is List
              ? (json['categories'] as List)
                  .map((e) => e is String ? e : (e is Map ? e['id'] : null))
                  .whereType<String>()
                  .toList()
              : const [],
      categoryNames:
          cats is List
              ? cats
                  .whereType<Map>()
                  .map((e) => e['name'] as String? ?? '')
                  .where((e) => e.isNotEmpty)
                  .toList()
              : const [],
      startsAt:
          DateTime.tryParse(json['startsAt'] as String? ?? '') ??
          DateTime.now(),
      endsAt:
          DateTime.tryParse(json['endsAt'] as String? ?? '') ?? DateTime.now(),
      isActive: json['isActive'] as bool? ?? true,
      deleted: json['deleted'] as bool? ?? false,
    );
  }
}
