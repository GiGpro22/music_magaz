import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../core/api_exceptions.dart';
import '../core/breakpoints.dart';
import '../core/validators.dart';
import '../models/brand.dart';
import '../models/category.dart';
import '../models/list_query.dart';
import '../models/role.dart';
import '../models/supplier.dart';
import '../repositories/catalog_repository.dart';
import '../state/auth_notifier.dart';
import '../state/entity_list_notifier.dart';
import '../widgets/entity_table.dart';
import '../widgets/generic_form_layout.dart';
import '../widgets/load_state_view.dart';
import '../widgets/pagination_bar.dart';

typedef SoftDeleter = Future<void> Function(String id);
typedef HardDeleter = Future<void> Function(String id);
typedef Restorer = Future<void> Function(String id);
typedef DeleteMany = Future<int> Function(List<String> ids);

class _EntityListScaffold<T> extends StatefulWidget {
  const _EntityListScaffold({
    required this.path,
    required this.notifier,
    required this.idOf,
    required this.columns,
    required this.titleOf,
    required this.subtitleOf,
    required this.canManage,
    required this.sortDefault,
    required this.isDeleted,
    this.softDelete,
    this.hardDelete,
    this.restore,
    this.deleteMany,
  });

  final String path;
  final EntityListNotifier<T> notifier;
  final String Function(T) idOf;
  final List<TableColumnSpec<T>> columns;
  final String Function(T) titleOf;
  final String Function(T) subtitleOf;
  final bool Function(Role) canManage;
  final String sortDefault;
  final bool Function(T) isDeleted;
  final SoftDeleter? softDelete;
  final HardDeleter? hardDelete;
  final Restorer? restore;
  final DeleteMany? deleteMany;

  @override
  State<_EntityListScaffold<T>> createState() => _EntityListScaffoldState<T>();
}

class _EntityListScaffoldState<T> extends State<_EntityListScaffold<T>> {
  final _search = TextEditingController();
  Timer? _debounce;
  bool _synced = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_synced) return;
    _synced = true;
    final q = ListQuery.fromQueryParams(
      GoRouterState.of(context).uri.queryParameters,
    );
    _search.text = q.search;
    widget.notifier.applyQuery(
      q.sortField == 'name' && widget.sortDefault != 'name'
          ? q.copyWith(sortField: widget.sortDefault)
          : q,
    );
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  void _push(ListQuery q) {
    final uri = Uri(path: widget.path, queryParameters: q.toQueryParams());
    context.replace(uri.toString());
    widget.notifier.applyQuery(q);
  }

  Future<void> _runDelete(Future<void> Function() action) async {
    try {
      await action();
      await widget.notifier.load();
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.message)));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final n = widget.notifier;
    final role = context.watch<AuthNotifier>().role;
    final wide = screenSizeOf(context) != ScreenSize.compact;

    return ListenableBuilder(
      listenable: n,
      builder: (context, _) {
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  SizedBox(
                    width: 260,
                    child: TextField(
                      controller: _search,
                      decoration: const InputDecoration(
                        labelText: 'Поиск',
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (v) {
                        _debounce?.cancel();
                        _debounce = Timer(
                          const Duration(milliseconds: 350),
                          () {
                            _push(n.query.copyWith(search: v));
                          },
                        );
                      },
                    ),
                  ),
                  if (Permissions.canRestore(role))
                    FilterChip(
                      label: const Text('Удалённые'),
                      selected: n.query.includeDeleted,
                      onSelected:
                          (v) => _push(n.query.copyWith(includeDeleted: v)),
                    ),
                  if (widget.canManage(role))
                    FilledButton.icon(
                      onPressed: () => context.go('${widget.path}/new'),
                      icon: const Icon(Icons.add),
                      label: const Text('Добавить'),
                    ),
                  if (n.hasSelection &&
                      widget.canManage(role) &&
                      (widget.deleteMany != null || widget.softDelete != null))
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
                        if (ok != true) return;
                        await _runDelete(() async {
                          final ids = n.selected.toList();
                          if (widget.deleteMany != null) {
                            await widget.deleteMany!(ids);
                          } else {
                            for (final id in ids) {
                              await widget.softDelete!(id);
                            }
                          }
                          n.clearSelection();
                        });
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
                child:
                    wide
                        ? EntityTable<T>(
                          items: n.result.items,
                          idOf: widget.idOf,
                          selected: n.selected,
                          onToggleSelect:
                              widget.canManage(role) &&
                                      widget.softDelete != null
                                  ? n.toggleSelection
                                  : null,
                          sortField: n.query.sortField,
                          sortAscending: n.query.sortAscending,
                          onSort:
                              (field) => _push(
                                n.query.copyWith(
                                  sortField: field,
                                  sortAscending:
                                      field == n.query.sortField
                                          ? !n.query.sortAscending
                                          : true,
                                ),
                              ),
                          columns: widget.columns,
                          actions:
                              widget.canManage(role)
                                  ? (item) => [
                                    if (!widget.isDeleted(item))
                                      IconButton(
                                        tooltip: 'Изменить',
                                        icon: const Icon(Icons.edit),
                                        onPressed:
                                            () => context.go(
                                              '${widget.path}/${widget.idOf(item)}/edit',
                                            ),
                                      ),
                                    if (!widget.isDeleted(item) &&
                                        widget.softDelete != null)
                                      IconButton(
                                        tooltip: 'В корзину',
                                        icon: const Icon(Icons.delete),
                                        onPressed:
                                            () => _runDelete(
                                              () => widget.softDelete!(
                                                widget.idOf(item),
                                              ),
                                            ),
                                      ),
                                    if (widget.isDeleted(item) &&
                                        widget.restore != null &&
                                        Permissions.canRestore(role))
                                      IconButton(
                                        tooltip: 'Восстановить',
                                        icon: const Icon(Icons.restore),
                                        onPressed:
                                            () => _runDelete(
                                              () => widget.restore!(
                                                widget.idOf(item),
                                              ),
                                            ),
                                      ),
                                    if (widget.hardDelete != null &&
                                        Permissions.canHardDelete(role))
                                      IconButton(
                                        tooltip: 'Удалить навсегда',
                                        icon: const Icon(Icons.delete_forever),
                                        onPressed:
                                            () => _runDelete(
                                              () => widget.hardDelete!(
                                                widget.idOf(item),
                                              ),
                                            ),
                                      ),
                                  ]
                                  : null,
                        )
                        : ListView.builder(
                          itemCount: n.result.items.length,
                          itemBuilder: (context, i) {
                            final item = n.result.items[i];
                            return ListTile(
                              title: Text(widget.titleOf(item)),
                              subtitle: Text(widget.subtitleOf(item)),
                              onTap:
                                  widget.canManage(role)
                                      ? () => context.go(
                                        '${widget.path}/${widget.idOf(item)}/edit',
                                      )
                                      : null,
                            );
                          },
                        ),
              ),
            ),
            PaginationBar(
              result: n.result,
              onPage: (p) => _push(n.query.copyWith(page: p)),
              onSize: (s) => _push(n.query.copyWith(size: s, page: 1)),
            ),
          ],
        );
      },
    );
  }
}

class BrandsScreen extends StatelessWidget {
  const BrandsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final repo = context.read<BrandRepository>();
    return _EntityListScaffold<Brand>(
      path: '/brands',
      notifier: context.watch<BrandListNotifier>(),
      idOf: (b) => b.id,
      titleOf: (b) => b.name,
      subtitleOf: (b) => b.country,
      canManage: Permissions.canManageCatalog,
      sortDefault: 'name',
      isDeleted: (b) => b.deleted,
      softDelete: repo.softDelete,
      hardDelete: repo.hardDelete,
      restore: repo.restore,
      deleteMany: repo.deleteMany,
      columns: [
        TableColumnSpec(
          label: 'Название',
          sortField: 'name',
          build: (b) => Text(b.name),
        ),
        TableColumnSpec(
          label: 'Страна',
          sortField: 'country',
          build: (b) => Text(b.country),
        ),
        TableColumnSpec(
          label: 'Сайт',
          build: (b) => Text(b.website, overflow: TextOverflow.ellipsis),
        ),
      ],
    );
  }
}

class BrandFormScreen extends StatefulWidget {
  const BrandFormScreen({super.key, this.id});
  final String? id;

  @override
  State<BrandFormScreen> createState() => _BrandFormScreenState();
}

class _BrandFormScreenState extends State<BrandFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _country = TextEditingController();
  final _website = TextEditingController();
  final _description = TextEditingController();
  bool _dirty = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    if (widget.id != null) {
      context.read<BrandRepository>().findById(widget.id!).then((b) {
        if (b == null || !mounted) return;
        setState(() {
          _name.text = b.name;
          _country.text = b.country;
          _website.text = b.website;
          _description.text = b.description;
        });
      });
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _country.dispose();
    _website.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final brand = Brand(
      id: widget.id ?? '',
      name: _name.text.trim(),
      country: _country.text.trim(),
      website: _website.text.trim(),
      description: _description.text.trim(),
    );
    try {
      final repo = context.read<BrandRepository>();
      widget.id == null ? await repo.create(brand) : await repo.update(brand);
      if (mounted) context.go('/brands');
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.message)));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: GenericFormLayout(
        formKey: _formKey,
        isDirty: _dirty,
        saving: _saving,
        title: widget.id == null ? 'Новый бренд' : 'Бренд',
        onSubmit: _submit,
        children: [
          TextFormField(
            controller: _name,
            decoration: const InputDecoration(
              labelText: 'Название',
              border: OutlineInputBorder(),
            ),
            onChanged: (_) => setState(() => _dirty = true),
            validator: V.combine([V.required(), V.length(min: 2)]),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _country,
            decoration: const InputDecoration(
              labelText: 'Страна',
              border: OutlineInputBorder(),
            ),
            onChanged: (_) => setState(() => _dirty = true),
            validator: V.required(),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _website,
            decoration: const InputDecoration(
              labelText: 'Сайт',
              border: OutlineInputBorder(),
            ),
            onChanged: (_) => setState(() => _dirty = true),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _description,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'Описание',
              border: OutlineInputBorder(),
            ),
            onChanged: (_) => setState(() => _dirty = true),
          ),
        ],
      ),
    );
  }
}

class CategoriesScreen extends StatelessWidget {
  const CategoriesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final repo = context.read<CategoryRepository>();
    return _EntityListScaffold<Category>(
      path: '/categories',
      notifier: context.watch<CategoryListNotifier>(),
      idOf: (c) => c.id,
      titleOf: (c) => c.name,
      subtitleOf: (c) => c.slug,
      canManage: Permissions.canManageCatalog,
      sortDefault: 'name',
      isDeleted: (c) => c.deleted,
      softDelete: repo.softDelete,
      hardDelete: repo.hardDelete,
      restore: repo.restore,
      deleteMany: repo.deleteMany,
      columns: [
        TableColumnSpec(
          label: 'Название',
          sortField: 'name',
          build: (c) => Text(c.name),
        ),
        TableColumnSpec(
          label: 'Slug',
          sortField: 'slug',
          build: (c) => Text(c.slug),
        ),
      ],
    );
  }
}

class CategoryFormScreen extends StatefulWidget {
  const CategoryFormScreen({super.key, this.id});
  final String? id;

  @override
  State<CategoryFormScreen> createState() => _CategoryFormScreenState();
}

class _CategoryFormScreenState extends State<CategoryFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _slug = TextEditingController();
  final _description = TextEditingController();
  bool _dirty = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    if (widget.id != null) {
      context.read<CategoryRepository>().findById(widget.id!).then((c) {
        if (c == null || !mounted) return;
        setState(() {
          _name.text = c.name;
          _slug.text = c.slug;
          _description.text = c.description;
        });
      });
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _slug.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final cat = Category(
      id: widget.id ?? '',
      name: _name.text.trim(),
      slug: _slug.text.trim(),
      description: _description.text.trim(),
    );
    try {
      final repo = context.read<CategoryRepository>();
      widget.id == null ? await repo.create(cat) : await repo.update(cat);
      if (mounted) context.go('/categories');
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.message)));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: GenericFormLayout(
        formKey: _formKey,
        isDirty: _dirty,
        saving: _saving,
        title: widget.id == null ? 'Новая категория' : 'Категория',
        onSubmit: _submit,
        children: [
          TextFormField(
            controller: _name,
            decoration: const InputDecoration(
              labelText: 'Название',
              border: OutlineInputBorder(),
            ),
            onChanged: (_) => setState(() => _dirty = true),
            validator: V.required(),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _slug,
            decoration: const InputDecoration(
              labelText: 'Slug',
              border: OutlineInputBorder(),
            ),
            onChanged: (_) => setState(() => _dirty = true),
            validator: V.required(),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _description,
            decoration: const InputDecoration(
              labelText: 'Описание',
              border: OutlineInputBorder(),
            ),
            onChanged: (_) => setState(() => _dirty = true),
          ),
        ],
      ),
    );
  }
}

class SuppliersScreen extends StatelessWidget {
  const SuppliersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final repo = context.read<SupplierRepository>();
    return _EntityListScaffold<Supplier>(
      path: '/suppliers',
      notifier: context.watch<SupplierListNotifier>(),
      idOf: (s) => s.id,
      titleOf: (s) => s.name,
      subtitleOf: (s) => '${s.city} · ${s.email}',
      canManage: Permissions.canManageSuppliers,
      sortDefault: 'name',
      isDeleted: (s) => s.deleted,
      softDelete: repo.softDelete,
      hardDelete: repo.hardDelete,
      restore: repo.restore,
      deleteMany: repo.deleteMany,
      columns: [
        TableColumnSpec(
          label: 'Название',
          sortField: 'name',
          build: (s) => Text(s.name),
        ),
        TableColumnSpec(
          label: 'Email',
          sortField: 'email',
          build: (s) => Text(s.email),
        ),
        TableColumnSpec(
          label: 'Город',
          sortField: 'city',
          build: (s) => Text(s.city),
        ),
      ],
    );
  }
}

class SupplierFormScreen extends StatefulWidget {
  const SupplierFormScreen({super.key, this.id});
  final String? id;

  @override
  State<SupplierFormScreen> createState() => _SupplierFormScreenState();
}

class _SupplierFormScreenState extends State<SupplierFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _city = TextEditingController();
  bool _dirty = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    if (widget.id != null) {
      context.read<SupplierRepository>().findById(widget.id!).then((s) {
        if (s == null || !mounted) return;
        setState(() {
          _name.text = s.name;
          _email.text = s.email;
          _phone.text = s.phone;
          _city.text = s.city;
        });
      });
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _phone.dispose();
    _city.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final s = Supplier(
      id: widget.id ?? '',
      name: _name.text.trim(),
      email: _email.text.trim(),
      phone: _phone.text.trim(),
      city: _city.text.trim(),
    );
    try {
      final repo = context.read<SupplierRepository>();
      widget.id == null ? await repo.create(s) : await repo.update(s);
      if (mounted) context.go('/suppliers');
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.message)));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: GenericFormLayout(
        formKey: _formKey,
        isDirty: _dirty,
        saving: _saving,
        title: widget.id == null ? 'Новый поставщик' : 'Поставщик',
        onSubmit: _submit,
        children: [
          TextFormField(
            controller: _name,
            decoration: const InputDecoration(
              labelText: 'Название',
              border: OutlineInputBorder(),
            ),
            onChanged: (_) => setState(() => _dirty = true),
            validator: V.required(),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _email,
            decoration: const InputDecoration(
              labelText: 'Email',
              border: OutlineInputBorder(),
            ),
            onChanged: (_) => setState(() => _dirty = true),
            validator: V.combine([V.required(), V.email()]),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _phone,
            decoration: const InputDecoration(
              labelText: 'Телефон',
              border: OutlineInputBorder(),
            ),
            onChanged: (_) => setState(() => _dirty = true),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _city,
            decoration: const InputDecoration(
              labelText: 'Город',
              border: OutlineInputBorder(),
            ),
            onChanged: (_) => setState(() => _dirty = true),
            validator: V.required(),
          ),
        ],
      ),
    );
  }
}
