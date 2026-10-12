import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../core/breakpoints.dart';
import '../models/brand.dart';
import '../models/category.dart';
import '../models/product.dart';
import '../models/role.dart';
import '../models/supplier.dart';
import '../repositories/catalog_repository.dart';
import '../state/auth_notifier.dart';
import '../state/cart_notifier.dart';
import '../state/entity_list_notifier.dart';
import '../widgets/entity_table.dart';
import '../widgets/load_state_view.dart';
import '../widgets/pagination_bar.dart';

class ProductsScreen extends StatefulWidget {
  const ProductsScreen({super.key});

  @override
  State<ProductsScreen> createState() => _ProductsScreenState();
}

class _ProductsScreenState extends State<ProductsScreen> {
  final _search = TextEditingController();
  final _focus = FocusNode();
  Timer? _debounce;
  List<Brand> _brands = [];
  List<Category> _categories = [];
  List<Supplier> _suppliers = [];
  bool _synced = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final brandRepo = context.read<BrandRepository>();
      final categoryRepo = context.read<CategoryRepository>();
      final supplierRepo = context.read<SupplierRepository>();
      final brands = await brandRepo.findAllActive();
      final cats = await categoryRepo.findAllActive();
      final suppliers = await supplierRepo.findAllActive();
      if (!mounted) return;
      setState(() {
        _brands = brands;
        _categories = cats;
        _suppliers = suppliers;
      });
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_synced) return;
    _synced = true;
    final params = GoRouterState.of(context).uri.queryParameters;
    final q = ProductQuery.fromQueryParams(params);
    _search.text = q.search;
    context.read<ProductListNotifier>().applyQuery(q);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _pushQuery(ProductQuery q) {
    final uri = Uri(path: '/products', queryParameters: q.toQueryParams());
    context.replace(uri.toString());
    context.read<ProductListNotifier>().applyQuery(q);
  }

  @override
  Widget build(BuildContext context) {
    final n = context.watch<ProductListNotifier>();
    final role = context.watch<AuthNotifier>().role;
    final wide = screenSizeOf(context) != ScreenSize.compact;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Wrap(
            spacing: 12,
            runSpacing: 12,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              SizedBox(
                width: 220,
                child: TextField(
                  controller: _search,
                  focusNode: _focus,
                  decoration: const InputDecoration(
                    labelText: 'Поиск',
                    border: OutlineInputBorder(),
                    isDense: true,
                    prefixIcon: Icon(Icons.search),
                  ),
                  onChanged: (v) {
                    _debounce?.cancel();
                    _debounce = Timer(const Duration(milliseconds: 350), () {
                      _pushQuery(n.query.copyWith(search: v));
                    });
                  },
                ),
              ),
              SizedBox(
                width: 200,
                child: DropdownButtonFormField<String?>(
                  value: n.query.brandId,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Бренд',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('Все')),
                    ..._brands.map(
                      (b) => DropdownMenuItem(
                        value: b.id,
                        child: Text(b.name, overflow: TextOverflow.ellipsis),
                      ),
                    ),
                  ],
                  onChanged:
                      (v) => _pushQuery(n.query.copyWith(brandId: v, page: 1)),
                ),
              ),
              SizedBox(
                width: 220,
                child: DropdownButtonFormField<String?>(
                  value: n.query.categoryId,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Категория',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('Все')),
                    ..._categories.map(
                      (c) => DropdownMenuItem(
                        value: c.id,
                        child: Text(c.name, overflow: TextOverflow.ellipsis),
                      ),
                    ),
                  ],
                  onChanged:
                      (v) =>
                          _pushQuery(n.query.copyWith(categoryId: v, page: 1)),
                ),
              ),
              SizedBox(
                width: 200,
                child: DropdownButtonFormField<String?>(
                  value: n.query.supplierId,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Поставщик',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('Все')),
                    ..._suppliers.map(
                      (s) => DropdownMenuItem(
                        value: s.id,
                        child: Text(s.name, overflow: TextOverflow.ellipsis),
                      ),
                    ),
                  ],
                  onChanged:
                      (v) =>
                          _pushQuery(n.query.copyWith(supplierId: v, page: 1)),
                ),
              ),
              FilterChip(
                label: const Text('Удалённые'),
                selected: n.query.includeDeleted,
                onSelected:
                    Permissions.canRestore(role)
                        ? (v) => _pushQuery(n.query.copyWith(includeDeleted: v))
                        : null,
              ),
              if (Permissions.canManageCatalog(role))
                FilledButton.icon(
                  onPressed: () => context.go('/products/new'),
                  icon: const Icon(Icons.add),
                  label: const Text('Добавить'),
                ),
              if (n.hasSelection && Permissions.canManageCatalog(role))
                FilledButton.tonalIcon(
                  onPressed: () async {
                    final ok = await showDialog<bool>(
                      context: context,
                      builder:
                          (ctx) => AlertDialog(
                            title: const Text('Удалить выбранные?'),
                            content: Text('Записей: ${n.selected.length}'),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(ctx, false),
                                child: const Text('Отмена'),
                              ),
                              FilledButton(
                                onPressed: () => Navigator.pop(ctx, true),
                                child: const Text('Удалить'),
                              ),
                            ],
                          ),
                    );
                    if (ok == true) await n.deleteSelected();
                  },
                  icon: const Icon(Icons.delete),
                  label: Text('Удалить (${n.selected.length})'),
                ),
            ],
          ),
        ),
        Expanded(
          child: LoadStateView(
            status: n.status,
            isEmpty: n.result.items.isEmpty,
            error: n.error,
            onRetry: n.load,
            emptyMessage: 'Товары не найдены',
            emptyAction: TextButton(
              onPressed: () => _pushQuery(const ProductQuery()),
              child: const Text('Сбросить фильтры'),
            ),
            child:
                wide
                    ? EntityTable<Product>(
                      items: n.result.items,
                      idOf: (p) => p.id,
                      selected: n.selected,
                      onToggleSelect:
                          Permissions.canManageCatalog(role)
                              ? n.toggleSelection
                              : null,
                      sortField: n.query.sortField,
                      sortAscending: n.query.sortAscending,
                      onSort:
                          (field) => _pushQuery(
                            n.query.copyWith(
                              sortField: field,
                              sortAscending:
                                  field == n.query.sortField
                                      ? !n.query.sortAscending
                                      : true,
                            ),
                          ),
                      columns: [
                        TableColumnSpec(
                          label: 'Название',
                          sortField: 'name',
                          build:
                              (p) =>
                                  Text(p.name, overflow: TextOverflow.ellipsis),
                        ),
                        TableColumnSpec(
                          label: 'SKU',
                          sortField: 'sku',
                          build: (p) => Text(p.sku),
                        ),
                        TableColumnSpec(
                          label: 'Бренд',
                          build: (p) => Text(p.brandName),
                        ),
                        TableColumnSpec(
                          label: 'Цена',
                          sortField: 'price',
                          numeric: true,
                          build: (p) => Text(p.price.toStringAsFixed(0)),
                        ),
                        TableColumnSpec(
                          label: 'Остаток',
                          sortField: 'stock',
                          numeric: true,
                          build: (p) => Text('${p.stock}'),
                        ),
                      ],
                      actions:
                          (p) => [
                            IconButton(
                              tooltip: 'Открыть',
                              icon: const Icon(Icons.visibility),
                              onPressed: () => context.go('/products/${p.id}'),
                            ),
                            if (Permissions.canPlaceOrder(role))
                              IconButton(
                                tooltip: 'В корзину',
                                icon: const Icon(Icons.add_shopping_cart),
                                onPressed: () {
                                  try {
                                    context.read<CartNotifier>().add(p);
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('Добавлено в корзину'),
                                      ),
                                    );
                                  } catch (e) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text('$e')),
                                    );
                                  }
                                },
                              ),
                            if (Permissions.canManageCatalog(role))
                              IconButton(
                                tooltip: 'Изменить',
                                icon: const Icon(Icons.edit),
                                onPressed:
                                    () => context.go('/products/${p.id}/edit'),
                              ),
                            if (p.deleted && Permissions.canRestore(role))
                              IconButton(
                                tooltip: 'Восстановить',
                                icon: const Icon(Icons.restore),
                                onPressed: () async {
                                  await context
                                      .read<ProductRepository>()
                                      .restore(p.id);
                                  await n.load();
                                },
                              ),
                            if (Permissions.canHardDelete(role))
                              IconButton(
                                tooltip: 'Удалить навсегда',
                                icon: const Icon(Icons.delete_forever),
                                onPressed: () async {
                                  await context
                                      .read<ProductRepository>()
                                      .hardDelete(p.id);
                                  await n.load();
                                },
                              ),
                          ],
                    )
                    : ListView.builder(
                      itemCount: n.result.items.length,
                      itemBuilder: (context, i) {
                        final p = n.result.items[i];
                        return Card(
                          margin: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          child: ListTile(
                            title: Text(
                              p.name,
                              overflow: TextOverflow.ellipsis,
                            ),
                            subtitle: Text(
                              '${p.brandName} · ${p.price.toStringAsFixed(0)} ₽ · остаток ${p.stock}',
                            ),
                            onTap: () => context.go('/products/${p.id}'),
                            trailing:
                                Permissions.canPlaceOrder(role)
                                    ? IconButton(
                                      tooltip: 'В корзину',
                                      icon: const Icon(Icons.add_shopping_cart),
                                      onPressed:
                                          () => context
                                              .read<CartNotifier>()
                                              .add(p),
                                    )
                                    : null,
                          ),
                        );
                      },
                    ),
          ),
        ),
        PaginationBar(
          result: n.result,
          onPage: (page) => _pushQuery(n.query.copyWith(page: page)),
          onSize: (size) => _pushQuery(n.query.copyWith(size: size, page: 1)),
        ),
      ],
    );
  }
}
