import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/api_client.dart';
import 'core/router.dart';
import 'repositories/auth_repository.dart';
import 'repositories/catalog_repository.dart';
import 'repositories/commerce_repository.dart';
import 'state/auth_notifier.dart';
import 'state/cart_notifier.dart';
import 'state/entity_list_notifier.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  usePathUrlStrategy();
  final prefs = await SharedPreferences.getInstance();

  late final AuthNotifier auth;
  late final Dio dio;

  dio = buildDio(
    tokenProvider: () => auth.token,
    onUnauthorized: () => auth.refreshToken(),
  );

  final authRepo = PbAuthRepository(dio);
  auth = AuthNotifier(prefs, authRepo);
  await auth.restore();

  runApp(
    MultiProvider(
      providers: [
        Provider<Dio>.value(value: dio),
        Provider<AuthRepository>.value(value: authRepo),
        ChangeNotifierProvider<AuthNotifier>.value(value: auth),
        Provider<BrandRepository>(create: (_) => PbBrandRepository(dio)),
        Provider<CategoryRepository>(create: (_) => PbCategoryRepository(dio)),
        Provider<SupplierRepository>(create: (_) => PbSupplierRepository(dio)),
        Provider<ProductRepository>(create: (_) => PbProductRepository(dio)),
        Provider<CustomerRepository>(create: (_) => PbCustomerRepository(dio)),
        Provider<LoyaltyCardRepository>(
          create: (_) => PbLoyaltyCardRepository(dio),
        ),
        Provider<PromotionRepository>(
          create: (_) => PbPromotionRepository(dio),
        ),
        Provider<OrderRepository>(create: (_) => PbOrderRepository(dio)),
        Provider<ReviewRepository>(create: (_) => PbReviewRepository(dio)),
        ChangeNotifierProvider(
          create: (c) => ProductListNotifier(c.read<ProductRepository>()),
        ),
        ChangeNotifierProvider(
          create: (c) => BrandListNotifier(c.read<BrandRepository>()),
        ),
        ChangeNotifierProvider(
          create: (c) => CategoryListNotifier(c.read<CategoryRepository>()),
        ),
        ChangeNotifierProvider(
          create: (c) => SupplierListNotifier(c.read<SupplierRepository>()),
        ),
        ChangeNotifierProvider(
          create: (c) => CustomerListNotifier(c.read<CustomerRepository>()),
        ),
        ChangeNotifierProvider(
          create: (c) => OrderListNotifier(c.read<OrderRepository>()),
        ),
        ChangeNotifierProvider(
          create: (c) => ReviewListNotifier(c.read<ReviewRepository>()),
        ),
        ChangeNotifierProvider(
          create: (c) => PromotionListNotifier(c.read<PromotionRepository>()),
        ),
        ChangeNotifierProvider(
          create:
              (c) => CartNotifier(
                products: c.read<ProductRepository>(),
                orders: c.read<OrderRepository>(),
                loyaltyCards: c.read<LoyaltyCardRepository>(),
                promotions: c.read<PromotionRepository>(),
              ),
        ),
      ],
      child: MusicShopApp(auth: auth),
    ),
  );
}

class MusicShopApp extends StatelessWidget {
  const MusicShopApp({super.key, required this.auth});
  final AuthNotifier auth;

  @override
  Widget build(BuildContext context) {
    final router = buildRouter(auth);
    return MaterialApp.router(
      title: 'Music Shop',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF0F4C5C),
          brightness: Brightness.light,
        ),
        useMaterial3: true,
      ),
      locale: const Locale('ru'),
      supportedLocales: const [Locale('ru'), Locale('en')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      routerConfig: router,
    );
  }
}
