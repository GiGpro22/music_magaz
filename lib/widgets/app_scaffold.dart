import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../core/breakpoints.dart';
import '../models/role.dart';
import '../state/auth_notifier.dart';
import '../state/cart_notifier.dart';

class NavItem {
  final String path;
  final String label;
  final IconData icon;
  final bool Function(Role role) visible;

  const NavItem({
    required this.path,
    required this.label,
    required this.icon,
    required this.visible,
  });
}

class AppScaffold extends StatelessWidget {
  const AppScaffold({super.key, required this.child});

  final Widget child;

  static final destinations = <NavItem>[
    NavItem(
      path: '/products',
      label: 'Каталог',
      icon: Icons.music_note,
      visible: Permissions.canBrowseCatalog,
    ),
    NavItem(
      path: '/brands',
      label: 'Бренды',
      icon: Icons.storefront,
      visible: Permissions.canManageCatalog,
    ),
    NavItem(
      path: '/categories',
      label: 'Категории',
      icon: Icons.category,
      visible: Permissions.canManageCatalog,
    ),
    NavItem(
      path: '/suppliers',
      label: 'Поставщики',
      icon: Icons.local_shipping,
      visible: Permissions.canManageSuppliers,
    ),
    NavItem(
      path: '/customers',
      label: 'Покупатели',
      icon: Icons.people,
      visible: Permissions.canManageCustomers,
    ),
    NavItem(
      path: '/orders',
      label: 'Заказы',
      icon: Icons.receipt_long,
      visible: Permissions.canProcessOrders,
    ),
    NavItem(
      path: '/my-orders',
      label: 'Мои заказы',
      icon: Icons.shopping_bag,
      visible: Permissions.canViewMyOrders,
    ),
    NavItem(
      path: '/cart',
      label: 'Корзина',
      icon: Icons.shopping_cart,
      visible: Permissions.canPlaceOrder,
    ),
    NavItem(
      path: '/reviews',
      label: 'Отзывы',
      icon: Icons.rate_review,
      visible: (r) => true,
    ),
    NavItem(
      path: '/promotions',
      label: 'Акции',
      icon: Icons.local_offer,
      visible: Permissions.canManagePromotions,
    ),
    NavItem(
      path: '/reports',
      label: 'Отчёты',
      icon: Icons.bar_chart,
      visible: Permissions.canViewReports,
    ),
    NavItem(
      path: '/admin/users',
      label: 'Пользователи',
      icon: Icons.admin_panel_settings,
      visible: Permissions.canManageUsers,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthNotifier>();
    final role = auth.role;
    final items = destinations.where((d) => d.visible(role)).toList();
    final location = GoRouterState.of(context).uri.path;
    var selected = items.indexWhere((d) => location.startsWith(d.path));
    if (selected < 0) selected = 0;
    final size = screenSizeOf(context);
    final cartCount = context.watch<CartNotifier>().totalQty;

    Widget body = child;
    final title =
        items.isEmpty
            ? 'Music Shop'
            : items[selected.clamp(0, items.length - 1)].label;

    if (size == ScreenSize.compact) {
      return Scaffold(
        appBar: AppBar(
          title: Text(title),
          actions: _actions(context, auth, cartCount),
        ),
        body: body,
        bottomNavigationBar:
            items.length <= 5
                ? NavigationBar(
                  selectedIndex: selected.clamp(0, items.length - 1),
                  onDestinationSelected: (i) => context.go(items[i].path),
                  destinations: [
                    for (final d in items)
                      NavigationDestination(icon: Icon(d.icon), label: d.label),
                  ],
                )
                : null,
        drawer:
            items.length > 5
                ? Drawer(
                  child: ListView(
                    children: [
                      const DrawerHeader(child: Text('Music Shop')),
                      for (final d in items)
                        ListTile(
                          leading: Icon(d.icon),
                          title: Text(d.label),
                          selected: location.startsWith(d.path),
                          onTap: () {
                            Navigator.pop(context);
                            context.go(d.path);
                          },
                        ),
                    ],
                  ),
                )
                : null,
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: _actions(context, auth, cartCount),
      ),
      body: Row(
        children: [
          NavigationRail(
            selectedIndex: selected.clamp(0, items.length - 1),
            onDestinationSelected: (i) => context.go(items[i].path),
            extended: size == ScreenSize.expanded,
            labelType:
                size == ScreenSize.expanded
                    ? NavigationRailLabelType.none
                    : NavigationRailLabelType.all,
            destinations: [
              for (final d in items)
                NavigationRailDestination(
                  icon: Icon(d.icon),
                  label: Text(d.label),
                ),
            ],
          ),
          const VerticalDivider(width: 1),
          Expanded(child: body),
        ],
      ),
    );
  }

  List<Widget> _actions(
    BuildContext context,
    AuthNotifier auth,
    int cartCount,
  ) {
    return [
      if (Permissions.canPlaceOrder(auth.role) && cartCount > 0)
        Badge(
          label: Text('$cartCount'),
          child: IconButton(
            tooltip: 'Корзина',
            onPressed: () => context.go('/cart'),
            icon: const Icon(Icons.shopping_cart),
          ),
        ),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Center(
          child: Text(auth.user?.name ?? '', overflow: TextOverflow.ellipsis),
        ),
      ),
      IconButton(
        tooltip: 'Выйти',
        onPressed: () async {
          await auth.logout();
          if (context.mounted) context.go('/login');
        },
        icon: const Icon(Icons.logout),
      ),
    ];
  }
}
