import 'package:dio/dio.dart';

import '../core/api_exceptions.dart';
import '../models/list_query.dart';
import '../models/page_result.dart';
import '../models/product.dart';

String escapeFilter(String value) {
  return value.replaceAll('\\', '\\\\').replaceAll('"', '\\"');
}

String buildSort(String field, bool ascending) => ascending ? field : '-$field';

Future<PageResult<T>> pbList<T>({
  required Dio dio,
  required String collection,
  required ListQuery query,
  required T Function(Map<String, dynamic>) fromJson,
  String searchFields = 'name',
  String? expand,
  String? extraFilter,
  CancelToken? cancelToken,
}) async {
  return guard(() async {
    final parts = <String>[];
    if (!query.includeDeleted) {
      parts.add('deleted=false');
    }
    if (query.search.trim().isNotEmpty) {
      final q = escapeFilter(query.search.trim());
      final fields = searchFields.split(',').map((f) => f.trim()).toList();
      final ors = fields.map((f) => '$f~"$q"').join(' || ');
      parts.add('($ors)');
    }
    for (final entry in query.filters.entries) {
      if (entry.value.isEmpty) continue;
      parts.add('${entry.key}="${escapeFilter(entry.value)}"');
    }
    if (extraFilter != null && extraFilter.isNotEmpty) {
      parts.add(extraFilter);
    }

    final response = await dio.get(
      '/api/collections/$collection/records',
      queryParameters: {
        'page': query.page,
        'perPage': query.size,
        'sort': buildSort(query.sortField, query.sortAscending),
        if (parts.isNotEmpty) 'filter': parts.join(' && '),
        if (expand != null) 'expand': expand,
      },
      cancelToken: cancelToken,
    );
    final data = response.data as Map<String, dynamic>;
    final items =
        (data['items'] as List? ?? [])
            .whereType<Map>()
            .map((e) => fromJson(Map<String, dynamic>.from(e)))
            .toList();
    return PageResult(
      items: items,
      page: data['page'] as int? ?? query.page,
      size: data['perPage'] as int? ?? query.size,
      total: data['totalItems'] as int? ?? items.length,
    );
  });
}

Future<PageResult<Product>> pbProductList({
  required Dio dio,
  required ProductQuery query,
  CancelToken? cancelToken,
}) async {
  return guard(() async {
    final parts = <String>[];
    if (!query.includeDeleted) parts.add('deleted=false');
    if (query.search.trim().isNotEmpty) {
      final q = escapeFilter(query.search.trim());
      parts.add('(name~"$q" || sku~"$q")');
    }
    if (query.brandId != null) {
      parts.add('brand="${escapeFilter(query.brandId!)}"');
    }
    if (query.supplierId != null) {
      parts.add('supplier="${escapeFilter(query.supplierId!)}"');
    }
    if (query.categoryId != null) {
      parts.add('categories~"${escapeFilter(query.categoryId!)}"');
    }
    if (query.priceFrom != null) parts.add('price>=${query.priceFrom}');
    if (query.priceTo != null) parts.add('price<=${query.priceTo}');

    final response = await dio.get(
      '/api/collections/products/records',
      queryParameters: {
        'page': query.page,
        'perPage': query.size,
        'sort': buildSort(query.sortField, query.sortAscending),
        if (parts.isNotEmpty) 'filter': parts.join(' && '),
        'expand': 'brand,supplier,categories',
      },
      cancelToken: cancelToken,
    );
    final data = response.data as Map<String, dynamic>;
    final items =
        (data['items'] as List? ?? [])
            .whereType<Map>()
            .map((e) => Product.fromJson(Map<String, dynamic>.from(e)))
            .toList();
    return PageResult(
      items: items,
      page: data['page'] as int? ?? query.page,
      size: data['perPage'] as int? ?? query.size,
      total: data['totalItems'] as int? ?? items.length,
    );
  });
}

Future<T> pbGet<T>({
  required Dio dio,
  required String collection,
  required String id,
  required T Function(Map<String, dynamic>) fromJson,
  String? expand,
}) {
  return guard(() async {
    final response = await dio.get(
      '/api/collections/$collection/records/$id',
      queryParameters: {if (expand != null) 'expand': expand},
    );
    return fromJson(Map<String, dynamic>.from(response.data as Map));
  });
}

Future<T> pbCreate<T>({
  required Dio dio,
  required String collection,
  required Map<String, dynamic> body,
  required T Function(Map<String, dynamic>) fromJson,
  String? expand,
}) {
  return guard(() async {
    final response = await dio.post(
      '/api/collections/$collection/records',
      data: body,
      queryParameters: {if (expand != null) 'expand': expand},
    );
    return fromJson(Map<String, dynamic>.from(response.data as Map));
  });
}

Future<T> pbUpdate<T>({
  required Dio dio,
  required String collection,
  required String id,
  required Map<String, dynamic> body,
  required T Function(Map<String, dynamic>) fromJson,
  String? expand,
}) {
  return guard(() async {
    final response = await dio.patch(
      '/api/collections/$collection/records/$id',
      data: body,
      queryParameters: {if (expand != null) 'expand': expand},
    );
    return fromJson(Map<String, dynamic>.from(response.data as Map));
  });
}

Future<void> pbDelete({
  required Dio dio,
  required String collection,
  required String id,
}) {
  return guard(() => dio.delete('/api/collections/$collection/records/$id'));
}

Future<int> pbCount({
  required Dio dio,
  required String collection,
  required String filter,
}) {
  return guard(() async {
    final response = await dio.get(
      '/api/collections/$collection/records',
      queryParameters: {'page': 1, 'perPage': 1, 'filter': filter},
    );
    final data = response.data as Map<String, dynamic>;
    return data['totalItems'] as int? ?? 0;
  });
}

/// Блокирует удаление, если есть связанные записи (как издательство↔книги в ПР3).
Future<void> ensureNoRelated({
  required Dio dio,
  required String collection,
  required String filter,
  required String entityLabel,
  required String relatedLabel,
}) async {
  final count = await pbCount(
    dio: dio,
    collection: collection,
    filter: filter,
  );
  if (count > 0) {
    throw ConflictException(
      'Нельзя удалить $entityLabel: связанных $relatedLabel — $count',
    );
  }
}
