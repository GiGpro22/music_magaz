import 'package:dio/dio.dart';

import '../core/api_exceptions.dart';
import '../models/brand.dart';
import '../models/category.dart';
import '../models/list_query.dart';
import '../models/page_result.dart';
import '../models/product.dart';
import '../models/supplier.dart';
import 'pb_helpers.dart';

abstract interface class BrandRepository {
  Future<PageResult<Brand>> find(ListQuery query, {CancelToken? cancelToken});
  Future<List<Brand>> findAllActive();
  Future<Brand?> findById(String id);
  Future<Brand> create(Brand brand);
  Future<Brand> update(Brand brand);
  Future<void> softDelete(String id);
  Future<void> hardDelete(String id);
  Future<void> restore(String id);
  Future<int> deleteMany(List<String> ids);
}

abstract interface class CategoryRepository {
  Future<PageResult<Category>> find(
    ListQuery query, {
    CancelToken? cancelToken,
  });
  Future<List<Category>> findAllActive();
  Future<Category?> findById(String id);
  Future<Category> create(Category category);
  Future<Category> update(Category category);
  Future<void> softDelete(String id);
  Future<void> hardDelete(String id);
  Future<void> restore(String id);
  Future<int> deleteMany(List<String> ids);
}

abstract interface class SupplierRepository {
  Future<PageResult<Supplier>> find(
    ListQuery query, {
    CancelToken? cancelToken,
  });
  Future<List<Supplier>> findAllActive();
  Future<Supplier?> findById(String id);
  Future<Supplier> create(Supplier supplier);
  Future<Supplier> update(Supplier supplier);
  Future<void> softDelete(String id);
  Future<void> hardDelete(String id);
  Future<void> restore(String id);
  Future<int> deleteMany(List<String> ids);
}

abstract interface class ProductRepository {
  Future<PageResult<Product>> find(
    ProductQuery query, {
    CancelToken? cancelToken,
  });
  Future<Product?> findById(String id);
  Future<Product> create(Product product);
  Future<Product> update(Product product);
  Future<void> softDelete(String id);
  Future<void> hardDelete(String id);
  Future<void> restore(String id);
  Future<int> deleteMany(List<String> ids);
  Future<void> decreaseStock(String id, int qty);
}

class PbBrandRepository implements BrandRepository {
  PbBrandRepository(this._dio);
  final Dio _dio;
  List<Brand>? _cache;

  @override
  Future<PageResult<Brand>> find(ListQuery query, {CancelToken? cancelToken}) =>
      pbList(
        dio: _dio,
        collection: 'brands',
        query: query,
        fromJson: Brand.fromJson,
        searchFields: 'name,country',
        cancelToken: cancelToken,
      );

  @override
  Future<List<Brand>> findAllActive() async {
    if (_cache != null) return _cache!;
    final page = await find(const ListQuery(size: 200));
    _cache = page.items.where((e) => !e.deleted).toList();
    return _cache!;
  }

  void _invalidate() => _cache = null;

  @override
  Future<Brand?> findById(String id) async {
    try {
      return await pbGet(
        dio: _dio,
        collection: 'brands',
        id: id,
        fromJson: Brand.fromJson,
      );
    } on NotFoundException {
      return null;
    }
  }

  @override
  Future<Brand> create(Brand brand) async {
    _invalidate();
    return pbCreate(
      dio: _dio,
      collection: 'brands',
      body: brand.toJson(),
      fromJson: Brand.fromJson,
    );
  }

  @override
  Future<Brand> update(Brand brand) async {
    _invalidate();
    return pbUpdate(
      dio: _dio,
      collection: 'brands',
      id: brand.id,
      body: brand.toJson(),
      fromJson: Brand.fromJson,
    );
  }

  Future<void> _assertNotUsedByProducts(String id) => ensureNoRelated(
    dio: _dio,
    collection: 'products',
    filter: 'brand="${escapeFilter(id)}"',
    entityLabel: 'бренд',
    relatedLabel: 'товаров',
  );

  @override
  Future<void> softDelete(String id) async {
    await _assertNotUsedByProducts(id);
    _invalidate();
    await pbUpdate(
      dio: _dio,
      collection: 'brands',
      id: id,
      body: {'deleted': true},
      fromJson: Brand.fromJson,
    );
  }

  @override
  Future<void> hardDelete(String id) async {
    await _assertNotUsedByProducts(id);
    _invalidate();
    await pbDelete(dio: _dio, collection: 'brands', id: id);
  }

  @override
  Future<void> restore(String id) async {
    _invalidate();
    await pbUpdate(
      dio: _dio,
      collection: 'brands',
      id: id,
      body: {'deleted': false},
      fromJson: Brand.fromJson,
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

class PbCategoryRepository implements CategoryRepository {
  PbCategoryRepository(this._dio);
  final Dio _dio;
  List<Category>? _cache;

  @override
  Future<PageResult<Category>> find(
    ListQuery query, {
    CancelToken? cancelToken,
  }) => pbList(
    dio: _dio,
    collection: 'categories',
    query: query,
    fromJson: Category.fromJson,
    searchFields: 'name,slug',
    cancelToken: cancelToken,
  );

  @override
  Future<List<Category>> findAllActive() async {
    if (_cache != null) return _cache!;
    final page = await find(const ListQuery(size: 200));
    _cache = page.items.where((e) => !e.deleted).toList();
    return _cache!;
  }

  void _invalidate() => _cache = null;

  @override
  Future<Category?> findById(String id) async {
    try {
      return await pbGet(
        dio: _dio,
        collection: 'categories',
        id: id,
        fromJson: Category.fromJson,
      );
    } on NotFoundException {
      return null;
    }
  }

  @override
  Future<Category> create(Category category) async {
    _invalidate();
    return pbCreate(
      dio: _dio,
      collection: 'categories',
      body: category.toJson(),
      fromJson: Category.fromJson,
    );
  }

  @override
  Future<Category> update(Category category) async {
    _invalidate();
    return pbUpdate(
      dio: _dio,
      collection: 'categories',
      id: category.id,
      body: category.toJson(),
      fromJson: Category.fromJson,
    );
  }

  Future<void> _assertNotUsedByProducts(String id) => ensureNoRelated(
    dio: _dio,
    collection: 'products',
    filter: 'categories~"${escapeFilter(id)}"',
    entityLabel: 'категорию',
    relatedLabel: 'товаров',
  );

  @override
  Future<void> softDelete(String id) async {
    await _assertNotUsedByProducts(id);
    _invalidate();
    await pbUpdate(
      dio: _dio,
      collection: 'categories',
      id: id,
      body: {'deleted': true},
      fromJson: Category.fromJson,
    );
  }

  @override
  Future<void> hardDelete(String id) async {
    await _assertNotUsedByProducts(id);
    _invalidate();
    await pbDelete(dio: _dio, collection: 'categories', id: id);
  }

  @override
  Future<void> restore(String id) async {
    _invalidate();
    await pbUpdate(
      dio: _dio,
      collection: 'categories',
      id: id,
      body: {'deleted': false},
      fromJson: Category.fromJson,
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

class PbSupplierRepository implements SupplierRepository {
  PbSupplierRepository(this._dio);
  final Dio _dio;
  List<Supplier>? _cache;

  @override
  Future<PageResult<Supplier>> find(
    ListQuery query, {
    CancelToken? cancelToken,
  }) => pbList(
    dio: _dio,
    collection: 'suppliers',
    query: query,
    fromJson: Supplier.fromJson,
    searchFields: 'name,email,city',
    cancelToken: cancelToken,
  );

  @override
  Future<List<Supplier>> findAllActive() async {
    if (_cache != null) return _cache!;
    final page = await find(const ListQuery(size: 200));
    _cache = page.items.where((e) => !e.deleted).toList();
    return _cache!;
  }

  void _invalidate() => _cache = null;

  @override
  Future<Supplier?> findById(String id) async {
    try {
      return await pbGet(
        dio: _dio,
        collection: 'suppliers',
        id: id,
        fromJson: Supplier.fromJson,
      );
    } on NotFoundException {
      return null;
    }
  }

  @override
  Future<Supplier> create(Supplier supplier) async {
    _invalidate();
    return pbCreate(
      dio: _dio,
      collection: 'suppliers',
      body: supplier.toJson(),
      fromJson: Supplier.fromJson,
    );
  }

  @override
  Future<Supplier> update(Supplier supplier) async {
    _invalidate();
    return pbUpdate(
      dio: _dio,
      collection: 'suppliers',
      id: supplier.id,
      body: supplier.toJson(),
      fromJson: Supplier.fromJson,
    );
  }

  Future<void> _assertNotUsedByProducts(String id) => ensureNoRelated(
    dio: _dio,
    collection: 'products',
    filter: 'supplier="${escapeFilter(id)}"',
    entityLabel: 'поставщика',
    relatedLabel: 'товаров',
  );

  @override
  Future<void> softDelete(String id) async {
    await _assertNotUsedByProducts(id);
    _invalidate();
    await pbUpdate(
      dio: _dio,
      collection: 'suppliers',
      id: id,
      body: {'deleted': true},
      fromJson: Supplier.fromJson,
    );
  }

  @override
  Future<void> hardDelete(String id) async {
    await _assertNotUsedByProducts(id);
    _invalidate();
    await pbDelete(dio: _dio, collection: 'suppliers', id: id);
  }

  @override
  Future<void> restore(String id) async {
    _invalidate();
    await pbUpdate(
      dio: _dio,
      collection: 'suppliers',
      id: id,
      body: {'deleted': false},
      fromJson: Supplier.fromJson,
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

class PbProductRepository implements ProductRepository {
  PbProductRepository(this._dio);
  final Dio _dio;

  @override
  Future<PageResult<Product>> find(
    ProductQuery query, {
    CancelToken? cancelToken,
  }) => pbProductList(dio: _dio, query: query, cancelToken: cancelToken);

  @override
  Future<Product?> findById(String id) async {
    try {
      return await pbGet(
        dio: _dio,
        collection: 'products',
        id: id,
        fromJson: Product.fromJson,
        expand: 'brand,supplier,categories',
      );
    } on NotFoundException {
      return null;
    }
  }

  @override
  Future<Product> create(Product product) => pbCreate(
    dio: _dio,
    collection: 'products',
    body: product.toJson(),
    fromJson: Product.fromJson,
    expand: 'brand,supplier,categories',
  );

  @override
  Future<Product> update(Product product) => pbUpdate(
    dio: _dio,
    collection: 'products',
    id: product.id,
    body: product.toJson(),
    fromJson: Product.fromJson,
    expand: 'brand,supplier,categories',
  );

  @override
  Future<void> softDelete(String id) => pbUpdate(
    dio: _dio,
    collection: 'products',
    id: id,
    body: {'deleted': true},
    fromJson: Product.fromJson,
  );

  @override
  Future<void> hardDelete(String id) =>
      pbDelete(dio: _dio, collection: 'products', id: id);

  @override
  Future<void> restore(String id) => pbUpdate(
    dio: _dio,
    collection: 'products',
    id: id,
    body: {'deleted': false},
    fromJson: Product.fromJson,
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

  @override
  Future<void> decreaseStock(String id, int qty) async {
    final product = await findById(id);
    if (product == null) throw const NotFoundException('Товар не найден');
    if (product.stock < qty) {
      throw ConflictException(
        'Недостаточно остатков для «${product.name}»: есть ${product.stock}, нужно $qty',
      );
    }
    // Только остаток — покупатель не должен перезаписывать весь товар.
    await pbUpdate(
      dio: _dio,
      collection: 'products',
      id: id,
      body: {'stock': product.stock - qty},
      fromJson: Product.fromJson,
    );
  }
}
