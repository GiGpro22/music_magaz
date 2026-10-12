import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' hide Category;

import '../core/api_exceptions.dart';
import '../models/brand.dart';
import '../models/category.dart';
import '../models/customer.dart';
import '../models/list_query.dart';
import '../models/order.dart';
import '../models/page_result.dart';
import '../models/product.dart';
import '../models/promotion.dart';
import '../models/review.dart';
import '../models/supplier.dart';
import '../repositories/catalog_repository.dart';
import '../repositories/commerce_repository.dart';

typedef PageLoader<T> =
    Future<PageResult<T>> Function(ListQuery query, {CancelToken? cancelToken});

class EntityListNotifier<T> extends ChangeNotifier {
  EntityListNotifier(this._loader, {ListQuery? initial})
    : _query = initial ?? const ListQuery();

  final PageLoader<T> _loader;
  ListQuery _query;
  PageResult<T> _result = PageResult.empty();
  LoadStatus _status = LoadStatus.idle;
  String? _error;
  final Set<String> _selected = {};
  CancelToken? _cancel;
  bool _disposed = false;

  ListQuery get query => _query;
  PageResult<T> get result => _result;
  LoadStatus get status => _status;
  String? get error => _error;
  Set<String> get selected => Set.unmodifiable(_selected);
  bool get hasSelection => _selected.isNotEmpty;

  Future<void> load() async {
    _cancel?.cancel();
    _cancel = CancelToken();
    _status = LoadStatus.loading;
    _error = null;
    _safeNotify();
    try {
      _result = await _loader(_query, cancelToken: _cancel);
      _status = LoadStatus.success;
    } on DioException catch (e) {
      if (CancelToken.isCancel(e)) return;
      _error = mapDioError(e).message;
      _status = LoadStatus.error;
    } on ApiException catch (e) {
      _error = e.message;
      _status = LoadStatus.error;
    } catch (e) {
      _error = '$e';
      _status = LoadStatus.error;
    }
    _safeNotify();
  }

  Future<void> applyQuery(ListQuery next) async {
    _query = next;
    _selected.clear();
    await load();
  }

  void toggleSelection(String id) {
    _selected.contains(id) ? _selected.remove(id) : _selected.add(id);
    _safeNotify();
  }

  void clearSelection() {
    _selected.clear();
    _safeNotify();
  }

  void _safeNotify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _cancel?.cancel();
    super.dispose();
  }
}

class ProductListNotifier extends ChangeNotifier {
  ProductListNotifier(this._repo, {ProductQuery? initial})
    : _query = initial ?? const ProductQuery();

  final ProductRepository _repo;
  ProductQuery _query;
  PageResult<Product> _result = PageResult.empty();
  LoadStatus _status = LoadStatus.idle;
  String? _error;
  final Set<String> _selected = {};
  CancelToken? _cancel;
  bool _disposed = false;

  ProductQuery get query => _query;
  PageResult<Product> get result => _result;
  LoadStatus get status => _status;
  String? get error => _error;
  Set<String> get selected => Set.unmodifiable(_selected);
  bool get hasSelection => _selected.isNotEmpty;

  Future<void> load() async {
    _cancel?.cancel();
    _cancel = CancelToken();
    _status = LoadStatus.loading;
    _error = null;
    _safeNotify();
    try {
      _result = await _repo.find(_query, cancelToken: _cancel);
      _status = LoadStatus.success;
    } on DioException catch (e) {
      if (CancelToken.isCancel(e)) return;
      _error = mapDioError(e).message;
      _status = LoadStatus.error;
    } on ApiException catch (e) {
      _error = e.message;
      _status = LoadStatus.error;
    } catch (e) {
      _error = '$e';
      _status = LoadStatus.error;
    }
    _safeNotify();
  }

  Future<void> applyQuery(ProductQuery next) async {
    _query = next;
    _selected.clear();
    await load();
  }

  void toggleSelection(String id) {
    _selected.contains(id) ? _selected.remove(id) : _selected.add(id);
    _safeNotify();
  }

  Future<void> deleteSelected() async {
    await _repo.deleteMany(_selected.toList());
    _selected.clear();
    await load();
  }

  void _safeNotify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _cancel?.cancel();
    super.dispose();
  }
}

class BrandListNotifier extends EntityListNotifier<Brand> {
  BrandListNotifier(BrandRepository repo)
    : super(
        (q, {cancelToken}) => repo.find(q, cancelToken: cancelToken),
        initial: const ListQuery(sortField: 'name'),
      );
}

class CategoryListNotifier extends EntityListNotifier<Category> {
  CategoryListNotifier(CategoryRepository repo)
    : super(
        (q, {cancelToken}) => repo.find(q, cancelToken: cancelToken),
        initial: const ListQuery(sortField: 'name'),
      );
}

class SupplierListNotifier extends EntityListNotifier<Supplier> {
  SupplierListNotifier(SupplierRepository repo)
    : super(
        (q, {cancelToken}) => repo.find(q, cancelToken: cancelToken),
        initial: const ListQuery(sortField: 'name'),
      );
}

class CustomerListNotifier extends EntityListNotifier<Customer> {
  CustomerListNotifier(CustomerRepository repo)
    : super(
        (q, {cancelToken}) => repo.find(q, cancelToken: cancelToken),
        initial: const ListQuery(sortField: 'fullName'),
      );
}

class OrderListNotifier extends EntityListNotifier<ShopOrder> {
  OrderListNotifier(OrderRepository repo)
    : super(
        (q, {cancelToken}) => repo.find(q, cancelToken: cancelToken),
        initial: const ListQuery(sortField: 'created', sortAscending: false),
      );
}

class ReviewListNotifier extends EntityListNotifier<Review> {
  ReviewListNotifier(ReviewRepository repo)
    : super(
        (q, {cancelToken}) => repo.find(q, cancelToken: cancelToken),
        initial: const ListQuery(sortField: 'rating', sortAscending: false),
      );
}

class PromotionListNotifier extends EntityListNotifier<Promotion> {
  PromotionListNotifier(PromotionRepository repo)
    : super(
        (q, {cancelToken}) => repo.find(q, cancelToken: cancelToken),
        initial: const ListQuery(sortField: 'title'),
      );
}
