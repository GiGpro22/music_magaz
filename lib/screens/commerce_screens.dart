import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../core/api_exceptions.dart';
import '../core/breakpoints.dart';
import '../core/validators.dart';
import '../models/customer.dart';
import '../models/list_query.dart';
import '../models/order.dart';
import '../models/promotion.dart';
import '../models/review.dart';
import '../models/role.dart';
import '../models/app_user.dart';
import '../models/product.dart';
import '../repositories/auth_repository.dart';
import '../repositories/catalog_repository.dart';
import '../repositories/commerce_repository.dart';
import '../state/auth_notifier.dart';
import '../state/cart_notifier.dart';
import '../state/entity_list_notifier.dart';
import '../state/order_pricing.dart';
import '../widgets/entity_table.dart';
import '../widgets/generic_form_layout.dart';
import '../widgets/load_state_view.dart';
import '../widgets/pagination_bar.dart';

class CustomersScreen extends StatefulWidget {
  const CustomersScreen({super.key});

  @override
  State<CustomersScreen> createState() => _CustomersScreenState();
}

class _CustomersScreenState extends State<CustomersScreen> {
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
    context.read<CustomerListNotifier>().applyQuery(
      q.copyWith(sortField: q.sortField == 'name' ? 'fullName' : q.sortField),
    );
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  void _push(ListQuery q) {
    context.replace(
      Uri(path: '/customers', queryParameters: q.toQueryParams()).toString(),
    );
    context.read<CustomerListNotifier>().applyQuery(q);
  }

  @override
  Widget build(BuildContext context) {
    final n = context.watch<CustomerListNotifier>();
    final wide = screenSizeOf(context) != ScreenSize.compact;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Wrap(
            spacing: 12,
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
                    _debounce = Timer(const Duration(milliseconds: 350), () {
                      _push(n.query.copyWith(search: v));
                    });
                  },
                ),
              ),
              if (Permissions.canRestore(
                context.watch<AuthNotifier>().role,
              ))
                FilterChip(
                  label: const Text('Удалённые'),
                  selected: n.query.includeDeleted,
                  onSelected:
                      (v) => _push(n.query.copyWith(includeDeleted: v)),
                ),
              FilledButton.icon(
                onPressed: () => context.go('/customers/new'),
                icon: const Icon(Icons.add),
                label: const Text('Добавить'),
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
                    ? EntityTable<Customer>(
                      items: n.result.items,
                      idOf: (c) => c.id,
                      columns: [
                        TableColumnSpec(
                          label: 'ФИО',
                          sortField: 'fullName',
                          build: (c) => Text(c.fullName),
                        ),
                        TableColumnSpec(
                          label: 'Email',
                          sortField: 'email',
                          build: (c) => Text(c.email),
                        ),
                        TableColumnSpec(
                          label: 'Город',
                          sortField: 'city',
                          build: (c) => Text(c.city),
                        ),
                      ],
                      actions: (c) {
                        final role = context.read<AuthNotifier>().role;
                        final repo = context.read<CustomerRepository>();
                        return [
                          if (!c.deleted)
                            IconButton(
                              tooltip: 'Изменить',
                              icon: const Icon(Icons.edit),
                              onPressed:
                                  () => context.go('/customers/${c.id}/edit'),
                            ),
                          if (!c.deleted)
                            IconButton(
                              tooltip: 'В корзину',
                              icon: const Icon(Icons.delete),
                              onPressed: () async {
                                try {
                                  await repo.softDelete(c.id);
                                  await n.load();
                                } on ApiException catch (e) {
                                  if (!context.mounted) return;
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text(e.message)),
                                  );
                                }
                              },
                            ),
                          if (c.deleted && Permissions.canRestore(role))
                            IconButton(
                              tooltip: 'Восстановить',
                              icon: const Icon(Icons.restore),
                              onPressed: () async {
                                await repo.restore(c.id);
                                await n.load();
                              },
                            ),
                          if (Permissions.canHardDelete(role))
                            IconButton(
                              tooltip: 'Удалить навсегда',
                              icon: const Icon(Icons.delete_forever),
                              onPressed: () async {
                                try {
                                  await repo.hardDelete(c.id);
                                  await n.load();
                                } on ApiException catch (e) {
                                  if (!context.mounted) return;
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text(e.message)),
                                  );
                                }
                              },
                            ),
                        ];
                      },
                    )
                    : ListView.builder(
                      itemCount: n.result.items.length,
                      itemBuilder: (_, i) {
                        final c = n.result.items[i];
                        return ListTile(
                          title: Text(c.fullName),
                          subtitle: Text(c.email),
                          onTap: () => context.go('/customers/${c.id}/edit'),
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
  }
}

class CustomerFormScreen extends StatefulWidget {
  const CustomerFormScreen({super.key, this.id});
  final String? id;

  @override
  State<CustomerFormScreen> createState() => _CustomerFormScreenState();
}

class _CustomerFormScreenState extends State<CustomerFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _fullName = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _city = TextEditingController();
  final _cardNumber = TextEditingController();
  LoyaltyLevel _level = LoyaltyLevel.bronze;
  bool _cardActive = true;
  String? _cardId;
  bool _dirty = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    if (widget.id != null) _load();
  }

  Future<void> _load() async {
    final customers = context.read<CustomerRepository>();
    final cards = context.read<LoyaltyCardRepository>();
    final c = await customers.findById(widget.id!);
    final card = await cards.findByCustomerId(widget.id!);
    if (!mounted || c == null) return;
    setState(() {
      _fullName.text = c.fullName;
      _email.text = c.email;
      _phone.text = c.phone;
      _city.text = c.city;
      if (card != null) {
        _cardId = card.id;
        _cardNumber.text = card.cardNumber;
        _level = card.level;
        _cardActive = card.isActive;
      }
    });
  }

  @override
  void dispose() {
    _fullName.dispose();
    _email.dispose();
    _phone.dispose();
    _city.dispose();
    _cardNumber.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final repo = context.read<CustomerRepository>();
      final cards = context.read<LoyaltyCardRepository>();
      final customer = Customer(
        id: widget.id ?? '',
        fullName: _fullName.text.trim(),
        email: _email.text.trim(),
        phone: _phone.text.trim(),
        city: _city.text.trim(),
      );
      final saved =
          widget.id == null
              ? await repo.create(customer)
              : await repo.update(customer);

      final card = LoyaltyCard(
        id: _cardId ?? '',
        customerId: saved.id,
        cardNumber: _cardNumber.text.trim(),
        level: _level,
        isActive: _cardActive,
        issuedAt: DateTime.now(),
      );
      if (_cardId == null) {
        await cards.create(card);
      } else {
        await cards.update(card);
      }
      if (mounted) context.go('/customers');
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
        title: widget.id == null ? 'Новый покупатель' : 'Покупатель и карта',
        onSubmit: _submit,
        children: [
          TextFormField(
            controller: _fullName,
            decoration: const InputDecoration(
              labelText: 'ФИО',
              border: OutlineInputBorder(),
            ),
            onChanged: (_) => setState(() => _dirty = true),
            validator: V.combine([V.required(), V.length(min: 2)]),
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
          ),
          const SizedBox(height: 24),
          Text(
            'Карта лояльности (1:1)',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _cardNumber,
            decoration: const InputDecoration(
              labelText: 'Номер карты',
              border: OutlineInputBorder(),
            ),
            onChanged: (_) => setState(() => _dirty = true),
            validator: V.required(),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<LoyaltyLevel>(
            value: _level,
            decoration: const InputDecoration(
              labelText: 'Уровень',
              border: OutlineInputBorder(),
            ),
            items:
                LoyaltyLevel.values
                    .map(
                      (l) => DropdownMenuItem(value: l, child: Text(l.label)),
                    )
                    .toList(),
            onChanged: (v) {
              if (v == null) return;
              setState(() {
                _level = v;
                _dirty = true;
              });
            },
          ),
          SwitchListTile(
            title: const Text('Карта активна'),
            value: _cardActive,
            onChanged:
                (v) => setState(() {
                  _cardActive = v;
                  _dirty = true;
                }),
          ),
        ],
      ),
    );
  }
}

class CartScreen extends StatefulWidget {
  const CartScreen({super.key});

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  PricingResult? _preview;
  String? _error;
  final _note = TextEditingController();

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _refreshPreview() async {
    final auth = context.read<AuthNotifier>();
    final customerId = auth.user?.customerId;
    if (customerId == null || customerId.isEmpty) {
      setState(
        () =>
            _error =
                'К аккаунту не привязан покупатель. Попросите продавца связать профиль.',
      );
      return;
    }
    try {
      final p = await context.read<CartNotifier>().preview(customerId);
      setState(() {
        _preview = p;
        _error = null;
      });
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _refreshPreview());
  }

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartNotifier>();
    if (cart.isEmpty) {
      return const Center(child: Text('Корзина пуста'));
    }
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              'Оформление заказа',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            const Text(
              'Стоимость считается с учётом карты лояльности и активных акций.',
            ),
            const SizedBox(height: 16),
            for (final line in cart.lines)
              ListTile(
                title: Text(line.product.name),
                subtitle: Text(
                  '${line.product.price.toStringAsFixed(0)} ₽ × ${line.qty}',
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      tooltip: 'Меньше',
                      onPressed: () {
                        cart.setQty(line.product.id, line.qty - 1);
                        _refreshPreview();
                      },
                      icon: const Icon(Icons.remove),
                    ),
                    Text('${line.qty}'),
                    IconButton(
                      tooltip: 'Больше',
                      onPressed: () {
                        try {
                          cart.setQty(line.product.id, line.qty + 1);
                          _refreshPreview();
                        } catch (e) {
                          ScaffoldMessenger.of(
                            context,
                          ).showSnackBar(SnackBar(content: Text('$e')));
                        }
                      },
                      icon: const Icon(Icons.add),
                    ),
                  ],
                ),
              ),
            TextField(
              controller: _note,
              decoration: const InputDecoration(
                labelText: 'Комментарий',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            if (_error != null)
              Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            if (_preview != null) ...[
              Text('Подытог: ${_preview!.subtotal.toStringAsFixed(2)} ₽'),
              Text(
                'Скидка лояльности: −${_preview!.loyaltyDiscount.toStringAsFixed(2)} ₽',
              ),
              Text(
                'Скидка по акциям: −${_preview!.promoDiscount.toStringAsFixed(2)} ₽',
              ),
              if (_preview!.appliedPromos.isNotEmpty)
                Text('Акции: ${_preview!.appliedPromos.join(', ')}'),
              Text(
                'Итого: ${_preview!.total.toStringAsFixed(2)} ₽',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ],
            const SizedBox(height: 16),
            FilledButton(
              onPressed:
                  cart.placing
                      ? null
                      : () async {
                        final customerId =
                            context.read<AuthNotifier>().user?.customerId;
                        if (customerId == null || customerId.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Не привязан покупатель'),
                            ),
                          );
                          return;
                        }
                        try {
                          final order = await cart.checkout(
                            customerId: customerId,
                            note: _note.text.trim(),
                          );
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Заказ ${order.id} создан'),
                              ),
                            );
                            context.go('/my-orders');
                          }
                        } on ApiException catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(
                              context,
                            ).showSnackBar(SnackBar(content: Text(e.message)));
                          }
                        }
                      },
              child:
                  cart.placing
                      ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                      : const Text('Оформить заказ'),
            ),
          ],
        ),
      ),
    );
  }
}

class OrdersScreen extends StatefulWidget {
  const OrdersScreen({super.key, this.mineOnly = false});
  final bool mineOnly;

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> {
  bool _synced = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_synced) return;
    _synced = true;
    final auth = context.read<AuthNotifier>();
    var q = ListQuery.fromQueryParams(
      GoRouterState.of(context).uri.queryParameters,
    ).copyWith(sortField: 'created', sortAscending: false, search: '');
    if (widget.mineOnly) {
      final cid = auth.user?.customerId;
      // Без своего customer никогда не показываем чужие заказы.
      q = q.copyWith(
        filters: {'customer': (cid == null || cid.isEmpty) ? '__none__' : cid},
      );
    }
    context.read<OrderListNotifier>().applyQuery(q);
  }

  void _push(ListQuery q) {
    final path = widget.mineOnly ? '/my-orders' : '/orders';
    var next = q;
    if (widget.mineOnly) {
      final cid = context.read<AuthNotifier>().user?.customerId;
      next = q.copyWith(
        filters: {'customer': (cid == null || cid.isEmpty) ? '__none__' : cid},
      );
    }
    context.replace(
      Uri(path: path, queryParameters: next.toQueryParams()).toString(),
    );
    context.read<OrderListNotifier>().applyQuery(next);
  }

  Future<void> _withRepo(
    Future<void> Function(OrderRepository repo) action,
  ) async {
    final repo = context.read<OrderRepository>();
    final list = context.read<OrderListNotifier>();
    try {
      await action(repo);
      await list.load();
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final n = context.watch<OrderListNotifier>();
    final role = context.watch<AuthNotifier>().role;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Wrap(
            spacing: 12,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                widget.mineOnly ? 'Мои заказы' : 'Журнал заказов',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              if (!widget.mineOnly && Permissions.canRestore(role))
                FilterChip(
                  label: const Text('Удалённые'),
                  selected: n.query.includeDeleted,
                  onSelected:
                      (v) => _push(n.query.copyWith(includeDeleted: v)),
                ),
            ],
          ),
        ),
        if (widget.mineOnly &&
            (context.watch<AuthNotifier>().user?.customerId == null ||
                context.watch<AuthNotifier>().user!.customerId!.isEmpty))
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              'Профиль покупателя не привязан — заказы не отображаются. '
              'Выйдите и войдите снова, либо зарегистрируйтесь заново.',
            ),
          ),
        Expanded(
          child: LoadStateView(
            status: n.status,
            isEmpty: n.result.items.isEmpty,
            error: n.error,
            onRetry: n.load,
            emptyMessage:
                widget.mineOnly ? 'У вас пока нет заказов' : 'Заказы не найдены',
            child: ListView.builder(
              itemCount: n.result.items.length,
              itemBuilder: (_, i) {
                final o = n.result.items[i];
                return Card(
                  margin: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 6,
                  ),
                  child: ListTile(
                    title: Text(
                      'Заказ ${o.id} · ${o.status.label}'
                      '${o.deleted ? ' · удалён' : ''}',
                    ),
                    subtitle: Text(
                      '${o.customerName.isEmpty ? o.customerId : o.customerName} · итого ${o.total.toStringAsFixed(0)} ₽',
                    ),
                    onTap: () => context.go('/orders/${o.id}'),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (!widget.mineOnly &&
                            !o.deleted &&
                            Permissions.canProcessOrders(role))
                          IconButton(
                            tooltip: 'В корзину',
                            icon: const Icon(Icons.delete),
                            onPressed:
                                () => _withRepo((r) => r.softDelete(o.id)),
                          ),
                        if (!widget.mineOnly &&
                            o.deleted &&
                            Permissions.canRestore(role))
                          IconButton(
                            tooltip: 'Восстановить',
                            icon: const Icon(Icons.restore),
                            onPressed: () => _withRepo((r) => r.restore(o.id)),
                          ),
                        if (!widget.mineOnly && Permissions.canHardDelete(role))
                          IconButton(
                            tooltip: 'Удалить навсегда',
                            icon: const Icon(Icons.delete_forever),
                            onPressed:
                                () => _withRepo((r) => r.hardDelete(o.id)),
                          ),
                        if (!o.deleted && Permissions.canProcessOrders(role))
                          PopupMenuButton<OrderStatus>(
                            tooltip: 'Статус',
                            onSelected: (s) async {
                              await context
                                  .read<OrderRepository>()
                                  .updateStatus(o.id, s);
                              await n.load();
                            },
                            itemBuilder:
                                (_) =>
                                    OrderStatus.values
                                        .map(
                                          (s) => PopupMenuItem(
                                            value: s,
                                            child: Text(s.label),
                                          ),
                                        )
                                        .toList(),
                          ),
                      ],
                    ),
                  ),
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
  }
}

class OrderDetailScreen extends StatefulWidget {
  const OrderDetailScreen({super.key, required this.id});
  final String id;

  @override
  State<OrderDetailScreen> createState() => _OrderDetailScreenState();
}

class _OrderDetailScreenState extends State<OrderDetailScreen> {
  ShopOrder? _order;

  @override
  void initState() {
    super.initState();
    context.read<OrderRepository>().findById(widget.id).then((o) {
      if (mounted) setState(() => _order = o);
    });
  }

  @override
  Widget build(BuildContext context) {
    final o = _order;
    if (o == null) return const Center(child: CircularProgressIndicator());
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text('Заказ ${o.id}', style: Theme.of(context).textTheme.titleLarge),
        Text('Статус: ${o.status.label}'),
        Text('Покупатель: ${o.customerName}'),
        Text('Подытог: ${o.subtotal.toStringAsFixed(2)}'),
        Text('Лояльность: −${o.loyaltyDiscount.toStringAsFixed(2)}'),
        Text('Акции: −${o.promoDiscount.toStringAsFixed(2)}'),
        Text('Итого: ${o.total.toStringAsFixed(2)}'),
        if (o.note.trim().isNotEmpty) ...[
          const SizedBox(height: 12),
          Text('Комментарий покупателя:', style: Theme.of(context).textTheme.titleSmall),
          Text(o.note),
        ],
        const SizedBox(height: 16),
        for (final item in o.items)
          ListTile(
            title: Text(
              item.productName.isEmpty ? item.productId : item.productName,
            ),
            subtitle: Text(
              '${item.qty} × ${item.unitPrice.toStringAsFixed(0)}',
            ),
            trailing: Text(item.lineTotal.toStringAsFixed(0)),
          ),
      ],
    );
  }
}

class ReviewsScreen extends StatefulWidget {
  const ReviewsScreen({super.key});

  @override
  State<ReviewsScreen> createState() => _ReviewsScreenState();
}

class _ReviewsScreenState extends State<ReviewsScreen> {
  bool _synced = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_synced) return;
    _synced = true;
    context.read<ReviewListNotifier>().applyQuery(
      ListQuery.fromQueryParams(
        GoRouterState.of(context).uri.queryParameters,
      ).copyWith(sortField: 'rating', sortAscending: false),
    );
  }

  void _push(ListQuery q) {
    context.replace(
      Uri(path: '/reviews', queryParameters: q.toQueryParams()).toString(),
    );
    context.read<ReviewListNotifier>().applyQuery(q);
  }

  Future<void> _withRepo(
    Future<void> Function(ReviewRepository repo) action,
  ) async {
    final repo = context.read<ReviewRepository>();
    final list = context.read<ReviewListNotifier>();
    try {
      await action(repo);
      await list.load();
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final n = context.watch<ReviewListNotifier>();
    final role = context.watch<AuthNotifier>().role;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Wrap(
            spacing: 12,
            runSpacing: 12,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text('Отзывы', style: Theme.of(context).textTheme.titleLarge),
              if (Permissions.canRestore(role))
                FilterChip(
                  label: const Text('Удалённые'),
                  selected: n.query.includeDeleted,
                  onSelected:
                      (v) => _push(n.query.copyWith(includeDeleted: v)),
                ),
              if (Permissions.canWriteReview(role))
                FilledButton.icon(
                  onPressed: () => context.go('/reviews/new'),
                  icon: const Icon(Icons.add),
                  label: const Text('Оставить отзыв'),
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
            child: ListView.builder(
              itemCount: n.result.items.length,
              itemBuilder: (_, i) {
                final r = n.result.items[i];
                return ListTile(
                  title: Text(
                    '${r.productName} · ${r.rating}/5'
                    '${r.deleted ? ' · удалён' : ''}',
                  ),
                  subtitle: Text('${r.customerName}: ${r.text}'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (!r.deleted &&
                          (Permissions.canWriteReview(role) ||
                              Permissions.canManageCatalog(role) ||
                              Permissions.canHardDelete(role)))
                        IconButton(
                          tooltip: 'В корзину',
                          icon: const Icon(Icons.delete),
                          onPressed: () => _withRepo((repo) => repo.softDelete(r.id)),
                        ),
                      if (r.deleted && Permissions.canRestore(role))
                        IconButton(
                          tooltip: 'Восстановить',
                          icon: const Icon(Icons.restore),
                          onPressed: () => _withRepo((repo) => repo.restore(r.id)),
                        ),
                      if (Permissions.canHardDelete(role))
                        IconButton(
                          tooltip: 'Удалить навсегда',
                          icon: const Icon(Icons.delete_forever),
                          onPressed:
                              () => _withRepo((repo) => repo.hardDelete(r.id)),
                        ),
                    ],
                  ),
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
  }
}

class ReviewFormScreen extends StatefulWidget {
  const ReviewFormScreen({super.key});

  @override
  State<ReviewFormScreen> createState() => _ReviewFormScreenState();
}

class _ReviewFormScreenState extends State<ReviewFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _text = TextEditingController();
  String? _productId;
  int _rating = 5;
  bool _saving = false;
  List<dynamic> _products = [];

  @override
  void initState() {
    super.initState();
    context.read<ProductRepository>().find(const ProductQuery(size: 100)).then((
      page,
    ) {
      if (mounted) setState(() => _products = page.items);
    });
  }

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: GenericFormLayout(
        formKey: _formKey,
        isDirty: true,
        saving: _saving,
        title: 'Новый отзыв',
        onSubmit: () async {
          if (!_formKey.currentState!.validate()) return;
          final customerId = context.read<AuthNotifier>().user?.customerId;
          if (customerId == null) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Не привязан покупатель')),
            );
            return;
          }
          setState(() => _saving = true);
          final reviews = context.read<ReviewRepository>();
          try {
            await reviews.create(
              Review(
                id: '',
                productId: _productId!,
                customerId: customerId,
                rating: _rating,
                text: _text.text.trim(),
              ),
            );
            if (!context.mounted) return;
            context.go('/reviews');
          } on ApiException catch (e) {
            if (!context.mounted) return;
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text(e.message)));
          } finally {
            if (mounted) setState(() => _saving = false);
          }
        },
        children: [
          DropdownButtonFormField<String>(
            value: _productId,
            decoration: const InputDecoration(
              labelText: 'Товар',
              border: OutlineInputBorder(),
            ),
            items:
                _products
                    .map(
                      (p) => DropdownMenuItem(
                        value: p.id as String,
                        child: Text(p.name as String),
                      ),
                    )
                    .toList(),
            onChanged: (v) => setState(() => _productId = v),
            validator: (v) => v == null ? 'Выберите товар' : null,
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<int>(
            value: _rating,
            decoration: const InputDecoration(
              labelText: 'Оценка',
              border: OutlineInputBorder(),
            ),
            items:
                [1, 2, 3, 4, 5]
                    .map((r) => DropdownMenuItem(value: r, child: Text('$r')))
                    .toList(),
            onChanged: (v) => setState(() => _rating = v ?? 5),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _text,
            maxLines: 4,
            decoration: const InputDecoration(
              labelText: 'Текст',
              border: OutlineInputBorder(),
            ),
            validator: V.combine([V.required(), V.length(min: 5)]),
          ),
        ],
      ),
    );
  }
}

class PromotionsScreen extends StatefulWidget {
  const PromotionsScreen({super.key});

  @override
  State<PromotionsScreen> createState() => _PromotionsScreenState();
}

class _PromotionsScreenState extends State<PromotionsScreen> {
  bool _synced = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_synced) return;
    _synced = true;
    context.read<PromotionListNotifier>().load();
  }

  void _push(ListQuery q) {
    context.replace(
      Uri(path: '/promotions', queryParameters: q.toQueryParams()).toString(),
    );
    context.read<PromotionListNotifier>().applyQuery(q);
  }

  Future<void> _withRepo(
    Future<void> Function(PromotionRepository repo) action,
  ) async {
    final repo = context.read<PromotionRepository>();
    final list = context.read<PromotionListNotifier>();
    try {
      await action(repo);
      await list.load();
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final n = context.watch<PromotionListNotifier>();
    final role = context.watch<AuthNotifier>().role;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Wrap(
            spacing: 12,
            runSpacing: 12,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text('Акции', style: Theme.of(context).textTheme.titleLarge),
              if (Permissions.canRestore(role))
                FilterChip(
                  label: const Text('Удалённые'),
                  selected: n.query.includeDeleted,
                  onSelected:
                      (v) => _push(n.query.copyWith(includeDeleted: v)),
                ),
              FilledButton.icon(
                onPressed: () => context.go('/promotions/new'),
                icon: const Icon(Icons.add),
                label: const Text('Добавить'),
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
            child: ListView.builder(
              itemCount: n.result.items.length,
              itemBuilder: (_, i) {
                final p = n.result.items[i];
                return ListTile(
                  title: Text(
                    '${p.title} (−${p.discountPercent.toStringAsFixed(0)}%)'
                    '${p.deleted ? ' · удалена' : ''}',
                  ),
                  subtitle: Text(
                    '${p.brandName.isEmpty ? 'Все бренды' : p.brandName} · ${p.categoryNames.join(', ')}',
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (!p.deleted)
                        IconButton(
                          tooltip: 'В корзину',
                          icon: const Icon(Icons.delete),
                          onPressed:
                              () => _withRepo((r) => r.softDelete(p.id)),
                        ),
                      if (p.deleted && Permissions.canRestore(role))
                        IconButton(
                          tooltip: 'Восстановить',
                          icon: const Icon(Icons.restore),
                          onPressed: () => _withRepo((r) => r.restore(p.id)),
                        ),
                      if (Permissions.canHardDelete(role))
                        IconButton(
                          tooltip: 'Удалить навсегда',
                          icon: const Icon(Icons.delete_forever),
                          onPressed:
                              () => _withRepo((r) => r.hardDelete(p.id)),
                        ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}

class PromotionFormScreen extends StatefulWidget {
  const PromotionFormScreen({super.key});

  @override
  State<PromotionFormScreen> createState() => _PromotionFormScreenState();
}

class _PromotionFormScreenState extends State<PromotionFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _percent = TextEditingController(text: '10');
  String? _brandId;
  final List<String> _categoryIds = [];
  List<dynamic> _brands = [];
  List<dynamic> _categories = [];
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final brandRepo = context.read<BrandRepository>();
    final categoryRepo = context.read<CategoryRepository>();
    Future.wait([brandRepo.findAllActive(), categoryRepo.findAllActive()]).then(
      (values) {
        if (!mounted) return;
        setState(() {
          _brands = values[0];
          _categories = values[1];
        });
      },
    );
  }

  @override
  void dispose() {
    _title.dispose();
    _percent.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: GenericFormLayout(
        formKey: _formKey,
        isDirty: true,
        saving: _saving,
        title: 'Новая акция',
        onSubmit: () async {
          if (!_formKey.currentState!.validate()) return;
          setState(() => _saving = true);
          final promos = context.read<PromotionRepository>();
          try {
            await promos.create(
              Promotion(
                id: '',
                title: _title.text.trim(),
                discountPercent: double.parse(_percent.text),
                brandId: _brandId,
                categoryIds: _categoryIds,
                startsAt: DateTime.now().subtract(const Duration(days: 1)),
                endsAt: DateTime.now().add(const Duration(days: 30)),
              ),
            );
            if (!context.mounted) return;
            context.go('/promotions');
          } on ApiException catch (e) {
            if (!context.mounted) return;
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text(e.message)));
          } finally {
            if (mounted) setState(() => _saving = false);
          }
        },
        children: [
          TextFormField(
            controller: _title,
            decoration: const InputDecoration(
              labelText: 'Название',
              border: OutlineInputBorder(),
            ),
            validator: V.required(),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _percent,
            decoration: const InputDecoration(
              labelText: 'Скидка %',
              border: OutlineInputBorder(),
            ),
            validator: V.number(min: 1, max: 90),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String?>(
            value: _brandId,
            decoration: const InputDecoration(
              labelText: 'Бренд (опц.)',
              border: OutlineInputBorder(),
            ),
            items: [
              const DropdownMenuItem(value: null, child: Text('Любой')),
              ..._brands.map(
                (b) => DropdownMenuItem(
                  value: b.id as String,
                  child: Text(b.name as String),
                ),
              ),
            ],
            onChanged: (v) => setState(() => _brandId = v),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            children:
                _categories.map((c) {
                  final id = c.id as String;
                  final selected = _categoryIds.contains(id);
                  return FilterChip(
                    label: Text(c.name as String),
                    selected: selected,
                    onSelected: (_) {
                      setState(() {
                        selected
                            ? _categoryIds.remove(id)
                            : _categoryIds.add(id);
                      });
                    },
                  );
                }).toList(),
          ),
        ],
      ),
    );
  }
}

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  double _revenue = 0;
  int _orders = 0;
  Map<String, double> _byStatus = {};
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final page = await context.read<OrderRepository>().find(
        const ListQuery(size: 200, sortField: 'created', sortAscending: false),
      );
      final byStatus = <String, double>{};
      var revenue = 0.0;
      for (final o in page.items) {
        if (o.status == OrderStatus.cancelled) continue;
        revenue += o.total;
        byStatus[o.status.label] = (byStatus[o.status.label] ?? 0) + o.total;
      }
      setState(() {
        _revenue = revenue;
        _orders = page.items.length;
        _byStatus = byStatus;
        _loading = false;
      });
    } on ApiException catch (e) {
      setState(() {
        _error = e.message;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_error!),
            FilledButton(onPressed: _load, child: const Text('Повторить')),
          ],
        ),
      );
    }
    final max = _byStatus.values.fold<double>(0, (a, b) => a > b ? a : b);
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text(
          'Отчёт по продажам',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 8),
        Text('Заказов: $_orders'),
        Text('Выручка (без отменённых): ${_revenue.toStringAsFixed(2)} ₽'),
        const SizedBox(height: 24),
        Text(
          'Распределение по статусам',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 12),
        for (final e in _byStatus.entries)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                SizedBox(width: 120, child: Text(e.key)),
                Expanded(
                  child: LinearProgressIndicator(
                    value: max == 0 ? 0 : e.value / max,
                    minHeight: 16,
                  ),
                ),
                const SizedBox(width: 8),
                Text(e.value.toStringAsFixed(0)),
              ],
            ),
          ),
      ],
    );
  }
}

class UsersAdminScreen extends StatefulWidget {
  const UsersAdminScreen({super.key});

  @override
  State<UsersAdminScreen> createState() => _UsersAdminScreenState();
}

class _UsersAdminScreenState extends State<UsersAdminScreen> {
  List<AppUser> _users = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final users = await context.read<AuthRepository>().listUsers();
      setState(() {
        _users = users;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = '$e';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(child: Text(_error!));
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _users.length,
      itemBuilder: (_, i) {
        final u = _users[i];
        return ListTile(
          title: Text(u.name),
          subtitle: Text('${u.email} · ${u.role.label}'),
          trailing: DropdownButton<Role>(
            value: u.role,
            items:
                Role.values
                    .map(
                      (r) => DropdownMenuItem(value: r, child: Text(r.label)),
                    )
                    .toList(),
            onChanged: (role) async {
              if (role == null) return;
              await context.read<AuthRepository>().updateUserRole(u.id, role);
              await _load();
            },
          ),
        );
      },
    );
  }
}
