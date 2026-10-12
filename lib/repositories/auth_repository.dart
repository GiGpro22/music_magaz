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
  Future<AppUser> me(String token);
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
      return AuthSession(token: token, user: AppUser.fromJson(record));
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
      return login(email, password);
    });
  }

  @override
  Future<AppUser> me(String token) {
    return guard(() async {
      final response = await _dio.get(
        '/api/collections/users/auth-refresh',
        options: Options(headers: {'Authorization': token}),
      );
      final data = response.data as Map<String, dynamic>;
      final record = Map<String, dynamic>.from(data['record'] as Map);
      return AppUser.fromJson(record);
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
