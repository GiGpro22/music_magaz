class Product {
  final String id;
  final String name;
  final String sku;
  final double price;
  final int stock;
  final int year;
  final String brandId;
  final String brandName;
  final String supplierId;
  final String supplierName;
  final List<String> categoryIds;
  final List<String> categoryNames;
  final String description;
  final bool deleted;

  const Product({
    required this.id,
    required this.name,
    required this.sku,
    required this.price,
    required this.stock,
    this.year = 0,
    required this.brandId,
    this.brandName = '',
    required this.supplierId,
    this.supplierName = '',
    this.categoryIds = const [],
    this.categoryNames = const [],
    this.description = '',
    this.deleted = false,
  });

  Product copyWith({
    String? name,
    String? sku,
    double? price,
    int? stock,
    int? year,
    String? brandId,
    String? brandName,
    String? supplierId,
    String? supplierName,
    List<String>? categoryIds,
    List<String>? categoryNames,
    String? description,
    bool? deleted,
  }) {
    return Product(
      id: id,
      name: name ?? this.name,
      sku: sku ?? this.sku,
      price: price ?? this.price,
      stock: stock ?? this.stock,
      year: year ?? this.year,
      brandId: brandId ?? this.brandId,
      brandName: brandName ?? this.brandName,
      supplierId: supplierId ?? this.supplierId,
      supplierName: supplierName ?? this.supplierName,
      categoryIds: categoryIds ?? this.categoryIds,
      categoryNames: categoryNames ?? this.categoryNames,
      description: description ?? this.description,
      deleted: deleted ?? this.deleted,
    );
  }

  Map<String, dynamic> toJson() => {
    'name': name,
    'sku': sku,
    'price': price,
    'stock': stock,
    'year': year,
    'brand': brandId,
    'supplier': supplierId,
    'categories': categoryIds,
    'description': description,
    'deleted': deleted,
  };

  factory Product.fromJson(Map<String, dynamic> json) {
    final expand = json['expand'] as Map<String, dynamic>? ?? {};
    final brand = expand['brand'];
    final supplier = expand['supplier'];
    final cats = expand['categories'];

    return Product(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      sku: json['sku'] as String? ?? '',
      price: (json['price'] as num?)?.toDouble() ?? 0,
      stock: (json['stock'] as num?)?.toInt() ?? 0,
      year: (json['year'] as num?)?.toInt() ?? 0,
      brandId: _relId(json['brand']) ?? '',
      brandName: brand is Map ? (brand['name'] as String? ?? '') : '',
      supplierId: _relId(json['supplier']) ?? '',
      supplierName: supplier is Map ? (supplier['name'] as String? ?? '') : '',
      categoryIds: _relIds(json['categories']),
      categoryNames:
          cats is List
              ? cats
                  .whereType<Map>()
                  .map((e) => e['name'] as String? ?? '')
                  .where((e) => e.isNotEmpty)
                  .toList()
              : const [],
      description: json['description'] as String? ?? '',
      deleted: json['deleted'] as bool? ?? false,
    );
  }

  static String? _relId(dynamic value) {
    if (value == null) return null;
    if (value is String) return value;
    if (value is Map) return value['id'] as String?;
    return null;
  }

  static List<String> _relIds(dynamic value) {
    if (value is List) {
      return value.map(_relId).whereType<String>().toList();
    }
    if (value is String && value.isNotEmpty) return [value];
    return const [];
  }
}

class ProductQuery {
  final String search;
  final String? brandId;
  final String? categoryId;
  final String? supplierId;
  final double? priceFrom;
  final double? priceTo;
  final String sortField;
  final bool sortAscending;
  final int page;
  final int size;
  final bool includeDeleted;

  const ProductQuery({
    this.search = '',
    this.brandId,
    this.categoryId,
    this.supplierId,
    this.priceFrom,
    this.priceTo,
    this.sortField = 'name',
    this.sortAscending = true,
    this.page = 1,
    this.size = 10,
    this.includeDeleted = false,
  });

  static const _unset = Object();

  ProductQuery copyWith({
    String? search,
    Object? brandId = _unset,
    Object? categoryId = _unset,
    Object? supplierId = _unset,
    Object? priceFrom = _unset,
    Object? priceTo = _unset,
    String? sortField,
    bool? sortAscending,
    int? page,
    int? size,
    bool? includeDeleted,
  }) {
    return ProductQuery(
      search: search ?? this.search,
      brandId: brandId == _unset ? this.brandId : brandId as String?,
      categoryId:
          categoryId == _unset ? this.categoryId : categoryId as String?,
      supplierId:
          supplierId == _unset ? this.supplierId : supplierId as String?,
      priceFrom: priceFrom == _unset ? this.priceFrom : priceFrom as double?,
      priceTo: priceTo == _unset ? this.priceTo : priceTo as double?,
      sortField: sortField ?? this.sortField,
      sortAscending: sortAscending ?? this.sortAscending,
      page: page ?? 1,
      size: size ?? this.size,
      includeDeleted: includeDeleted ?? this.includeDeleted,
    );
  }

  Map<String, String> toQueryParams() {
    return {
      if (search.trim().isNotEmpty) 'q': search.trim(),
      if (brandId != null) 'brandId': brandId!,
      if (categoryId != null) 'categoryId': categoryId!,
      if (supplierId != null) 'supplierId': supplierId!,
      if (priceFrom != null) 'priceFrom': '$priceFrom',
      if (priceTo != null) 'priceTo': '$priceTo',
      'sort': sortField,
      'asc': '$sortAscending',
      'page': '$page',
      'size': '$size',
      if (includeDeleted) 'deleted': '1',
    };
  }

  factory ProductQuery.fromQueryParams(Map<String, String> p) {
    return ProductQuery(
      search: p['q'] ?? '',
      brandId: p['brandId'],
      categoryId: p['categoryId'],
      supplierId: p['supplierId'],
      priceFrom: double.tryParse(p['priceFrom'] ?? ''),
      priceTo: double.tryParse(p['priceTo'] ?? ''),
      sortField: p['sort'] ?? 'name',
      sortAscending: p['asc'] != 'false',
      page: int.tryParse(p['page'] ?? '') ?? 1,
      size: int.tryParse(p['size'] ?? '') ?? 10,
      includeDeleted: p['deleted'] == '1',
    );
  }
}
