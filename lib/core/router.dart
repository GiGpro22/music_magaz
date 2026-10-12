import 'package:go_router/go_router.dart';

import '../models/role.dart';
import '../screens/auth_screens.dart';
import '../screens/commerce_screens.dart';
import '../screens/product_form_screen.dart';
import '../screens/products_screen.dart';
import '../screens/simple_entity_screens.dart';
import '../state/auth_notifier.dart';
import '../widgets/app_scaffold.dart';

GoRouter buildRouter(AuthNotifier auth) {
  String? roleGuard(bool Function(Role role) allowed) {
    if (!auth.isAuthenticated) return '/login';
    if (!allowed(auth.role)) return '/forbidden';
    return null;
  }

  return GoRouter(
    refreshListenable: auth,
    initialLocation: '/products',
    redirect: (context, state) {
      if (auth.isRestoring) return null;
      final loggedIn = auth.isAuthenticated;
      final path = state.matchedLocation;
      final isPublic = path == '/login' || path == '/register';

      if (!loggedIn && !isPublic) {
        return '/login?from=${Uri.encodeComponent(state.uri.toString())}';
      }
      if (loggedIn && isPublic) return '/products';
      return null;
    },
    routes: [
      GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
      GoRoute(path: '/register', builder: (_, __) => const RegisterScreen()),
      GoRoute(path: '/forbidden', builder: (_, __) => const ForbiddenScreen()),
      ShellRoute(
        builder: (context, state, child) => AppScaffold(child: child),
        routes: [
          GoRoute(
            path: '/products',
            builder: (_, __) => const ProductsScreen(),
            routes: [
              GoRoute(
                path: 'new',
                redirect:
                    (_, __) =>
                        roleGuard((r) => Permissions.canManageCatalog(r)),
                builder: (_, __) => const ProductFormScreen(),
              ),
              GoRoute(
                path: ':id',
                builder:
                    (_, state) =>
                        ProductDetailScreen(id: state.pathParameters['id']!),
                routes: [
                  GoRoute(
                    path: 'edit',
                    redirect:
                        (_, __) =>
                            roleGuard((r) => Permissions.canManageCatalog(r)),
                    builder:
                        (_, state) =>
                            ProductFormScreen(id: state.pathParameters['id']),
                  ),
                ],
              ),
            ],
          ),
          GoRoute(
            path: '/brands',
            redirect:
                (_, __) => roleGuard((r) => Permissions.canManageCatalog(r)),
            builder: (_, __) => const BrandsScreen(),
            routes: [
              GoRoute(path: 'new', builder: (_, __) => const BrandFormScreen()),
              GoRoute(
                path: ':id/edit',
                builder:
                    (_, state) =>
                        BrandFormScreen(id: state.pathParameters['id']),
              ),
            ],
          ),
          GoRoute(
            path: '/categories',
            redirect:
                (_, __) => roleGuard((r) => Permissions.canManageCatalog(r)),
            builder: (_, __) => const CategoriesScreen(),
            routes: [
              GoRoute(
                path: 'new',
                builder: (_, __) => const CategoryFormScreen(),
              ),
              GoRoute(
                path: ':id/edit',
                builder:
                    (_, state) =>
                        CategoryFormScreen(id: state.pathParameters['id']),
              ),
            ],
          ),
          GoRoute(
            path: '/suppliers',
            redirect:
                (_, __) => roleGuard((r) => Permissions.canManageSuppliers(r)),
            builder: (_, __) => const SuppliersScreen(),
            routes: [
              GoRoute(
                path: 'new',
                builder: (_, __) => const SupplierFormScreen(),
              ),
              GoRoute(
                path: ':id/edit',
                builder:
                    (_, state) =>
                        SupplierFormScreen(id: state.pathParameters['id']),
              ),
            ],
          ),
          GoRoute(
            path: '/customers',
            redirect:
                (_, __) => roleGuard((r) => Permissions.canManageCustomers(r)),
            builder: (_, __) => const CustomersScreen(),
            routes: [
              GoRoute(
                path: 'new',
                builder: (_, __) => const CustomerFormScreen(),
              ),
              GoRoute(
                path: ':id/edit',
                builder:
                    (_, state) =>
                        CustomerFormScreen(id: state.pathParameters['id']),
              ),
            ],
          ),
          GoRoute(
            path: '/orders',
            redirect:
                (_, __) => roleGuard((r) => Permissions.canProcessOrders(r)),
            builder: (_, __) => const OrdersScreen(),
            routes: [
              GoRoute(
                path: ':id',
                builder:
                    (_, state) =>
                        OrderDetailScreen(id: state.pathParameters['id']!),
              ),
            ],
          ),
          GoRoute(
            path: '/my-orders',
            redirect:
                (_, __) => roleGuard((r) => Permissions.canViewMyOrders(r)),
            builder: (_, __) => const OrdersScreen(mineOnly: true),
          ),
          GoRoute(
            path: '/cart',
            redirect: (_, __) => roleGuard((r) => Permissions.canPlaceOrder(r)),
            builder: (_, __) => const CartScreen(),
          ),
          GoRoute(
            path: '/reviews',
            builder: (_, __) => const ReviewsScreen(),
            routes: [
              GoRoute(
                path: 'new',
                redirect:
                    (_, __) => roleGuard((r) => Permissions.canWriteReview(r)),
                builder: (_, __) => const ReviewFormScreen(),
              ),
            ],
          ),
          GoRoute(
            path: '/promotions',
            redirect:
                (_, __) => roleGuard((r) => Permissions.canManagePromotions(r)),
            builder: (_, __) => const PromotionsScreen(),
            routes: [
              GoRoute(
                path: 'new',
                builder: (_, __) => const PromotionFormScreen(),
              ),
            ],
          ),
          GoRoute(
            path: '/reports',
            redirect:
                (_, __) => roleGuard((r) => Permissions.canViewReports(r)),
            builder: (_, __) => const ReportsScreen(),
          ),
          GoRoute(
            path: '/admin/users',
            redirect:
                (_, __) => roleGuard((r) => Permissions.canManageUsers(r)),
            builder: (_, __) => const UsersAdminScreen(),
          ),
        ],
      ),
    ],
    errorBuilder:
        (context, state) => NotFoundScreen(location: state.uri.toString()),
  );
}
