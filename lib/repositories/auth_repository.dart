import 'package:dio/dio.dart';

import '../core/api_exceptions.dart';
import '../models/app_user.dart';
import '../models/role.dart';

class AuthSession {
  final String token;
  final AppUser user;

  const AuthSession({required this.token, required this.user});
}

abstract interface class AuthRepository {
  Future<AuthSession> login(String email, String password);
  Future<AuthSession> register({
    required String email,
    required String password,
    required String name,
  });
  /// Обновляет JWT через auth-refresh и возвращает новую сессию.
  Future<AuthSession> refresh(String token);
  Future<List<AppUser>> listUsers();
  Future<AppUser> updateUserRole(String id, Role role);
}

class PbAuthRepository implements AuthRepository {
  PbAuthRepository(this._dio);
  final Dio _dio;

  @override
  Future<AuthSession> login(String email, String password) {
    return guard(() async {
      final response = await _dio.post(
        '/api/collections/users/auth-with-password',
        data: {'identity': email, 'password': password},
      );
      final data = response.data as Map<String, dynamic>;
      final token = data['token'] as String? ?? '';
      final record = Map<String, dynamic>.from(data['record'] as Map);
      var session = AuthSession(
        token: token,
        user: AppUser.fromJson(record),
      );
      session = await _ensureCustomerProfile(session, name: session.user.name);
      return session;
    });
  }

  @override
  Future<AuthSession> register({
    required String email,
    required String password,
    required String name,
  }) {
    return guard(() async {
      await _dio.post(
        '/api/collections/users/records',
        data: {
          'email': email,
          'password': password,
          'passwordConfirm': password,
          'name': name,
          'role': Role.customer.name,
        },
      );
      // login → _ensureCustomerProfile создаёт покупателя и привязывает.
      return login(email, password);
    });
  }

  /// У покупателя без связи users.customer создаёт/находит покупателя и привязывает.
  Future<AuthSession> _ensureCustomerProfile(
    AuthSession session, {
    required String name,
  }) async {
    final user = session.user;
    if (user.role != Role.customer) return session;
    if (user.customerId != null && user.customerId!.isNotEmpty) {
      return session;
    }

    String? customerId;
    final found = await _dio.get(
      '/api/collections/customers/records',
      queryParameters: {
        'page': 1,
        'perPage': 1,
        'filter': 'email="${user.email.replaceAll('"', '\\"')}"',
      },
      options: Options(headers: {'Authorization': session.token}),
    );
    final items = (found.data as Map)['items'] as List? ?? [];
    if (items.isNotEmpty) {
      customerId = (items.first as Map)['id'] as String?;
    } else {
      final created = await _dio.post(
        '/api/collections/customers/records',
        data: {
          'fullName': name.trim().isEmpty ? user.email : name.trim(),
          'email': user.email,
          'deleted': false,
        },
        options: Options(headers: {'Authorization': session.token}),
      );
      customerId = (created.data as Map)['id'] as String?;
    }

    if (customerId == null || customerId.isEmpty) return session;

    await _dio.patch(
      '/api/collections/users/records/${user.id}',
      data: {'customer': customerId},
      options: Options(headers: {'Authorization': session.token}),
    );

    try {
      final cards = await _dio.get(
        '/api/collections/loyalty_cards/records',
        queryParameters: {
          'page': 1,
          'perPage': 1,
          'filter': 'customer="$customerId"',
        },
        options: Options(headers: {'Authorization': session.token}),
      );
      final cardItems = (cards.data as Map)['items'] as List? ?? [];
      if (cardItems.isEmpty) {
        await _dio.post(
          '/api/collections/loyalty_cards/records',
          data: {
            'customer': customerId,
            'cardNumber': 'C-${customerId.substring(0, 8).toUpperCase()}',
            'level': 'bronze',
            'points': 0,
            'isActive': true,
            'issuedAt': DateTime.now().toUtc().toIso8601String(),
            'deleted': false,
          },
          options: Options(headers: {'Authorization': session.token}),
        );
      }
    } catch (_) {
      // Карта необязательна — заказ без неё всё равно возможен.
    }

    return refresh(session.token);
  }

  @override
  Future<AuthSession> refresh(String token) {
    return guard(() async {
      final response = await _dio.post(
        '/api/collections/users/auth-refresh',
        options: Options(headers: {'Authorization': token}),
      );
      final data = response.data as Map<String, dynamic>;
      final newToken = data['token'] as String? ?? token;
      final record = Map<String, dynamic>.from(data['record'] as Map);
      return AuthSession(token: newToken, user: AppUser.fromJson(record));
    });
  }

  @override
  Future<List<AppUser>> listUsers() {
    return guard(() async {
      final response = await _dio.get(
        '/api/collections/users/records',
        queryParameters: {'page': 1, 'perPage': 100, 'sort': 'email'},
      );
      final items = (response.data as Map)['items'] as List? ?? [];
      return items
          .whereType<Map>()
          .map((e) => AppUser.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    });
  }

  @override
  Future<AppUser> updateUserRole(String id, Role role) {
    return guard(() async {
      final response = await _dio.patch(
        '/api/collections/users/records/$id',
        data: {'role': role.name},
      );
      return AppUser.fromJson(Map<String, dynamic>.from(response.data as Map));
    });
  }
}
