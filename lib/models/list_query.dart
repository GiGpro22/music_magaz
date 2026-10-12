class ListQuery {
  final String search;
  final String sortField;
  final bool sortAscending;
  final int page;
  final int size;
  final bool includeDeleted;
  final Map<String, String> filters;

  const ListQuery({
    this.search = '',
    this.sortField = 'name',
    this.sortAscending = true,
    this.page = 1,
    this.size = 10,
    this.includeDeleted = false,
    this.filters = const {},
  });

  ListQuery copyWith({
    String? search,
    String? sortField,
    bool? sortAscending,
    int? page,
    int? size,
    bool? includeDeleted,
    Map<String, String>? filters,
  }) {
    return ListQuery(
      search: search ?? this.search,
      sortField: sortField ?? this.sortField,
      sortAscending: sortAscending ?? this.sortAscending,
      page: page ?? 1,
      size: size ?? this.size,
      includeDeleted: includeDeleted ?? this.includeDeleted,
      filters: filters ?? this.filters,
    );
  }

  Map<String, String> toQueryParams() => {
    if (search.trim().isNotEmpty) 'q': search.trim(),
    'sort': sortField,
    'asc': '$sortAscending',
    'page': '$page',
    'size': '$size',
    if (includeDeleted) 'deleted': '1',
    ...filters,
  };

  factory ListQuery.fromQueryParams(Map<String, String> p) {
    final known = {'q', 'sort', 'asc', 'page', 'size', 'deleted'};
    final filters = Map<String, String>.fromEntries(
      p.entries.where((e) => !known.contains(e.key)),
    );
    return ListQuery(
      search: p['q'] ?? '',
      sortField: p['sort'] ?? 'name',
      sortAscending: p['asc'] != 'false',
      page: int.tryParse(p['page'] ?? '') ?? 1,
      size: int.tryParse(p['size'] ?? '') ?? 10,
      includeDeleted: p['deleted'] == '1',
      filters: filters,
    );
  }
}
