import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/app_user.dart';
import '../models/role.dart';
import '../repositories/auth_repository.dart';

class AuthNotifier extends ChangeNotifier {
  static const _kToken = 'auth_token';

  AuthNotifier(this._prefs, this._auth);

  final SharedPreferences _prefs;
  final AuthRepository _auth;

  AppUser? _user;
  String? _token;
  bool _disposed = false;
  bool _restoring = true;

  AppUser? get user => _user;
  String? get token => _token;
  bool get isAuthenticated => _user != null && _token != null;
  bool get isRestoring => _restoring;
  Role get role => _user?.role ?? Role.customer;

  bool has(Role required) =>
      _user != null && _user!.role.level >= required.level;

  bool hasExact(Role required) => _user?.role == required;

  Future<void> restore() async {
    _restoring = true;
    _safeNotify();
    final saved = _prefs.getString(_kToken);
    if (saved == null || saved.isEmpty) {
      _restoring = false;
      _safeNotify();
      return;
    }
    _token = saved;
    try {
      final session = await _auth.refresh(saved);
      _token = session.token;
      _user = session.user;
      if (session.token != saved) {
        await _prefs.setString(_kToken, session.token);
      }
    } catch (_) {
      await logout();
    }
    _restoring = false;
    _safeNotify();
  }

  Future<void> login(String email, String password) async {
    final session = await _auth.login(email, password);
    _token = session.token;
    _user = session.user;
    await _prefs.setString(_kToken, session.token);
    _safeNotify();
  }

  Future<void> register({
    required String email,
    required String password,
    required String name,
  }) async {
    final session = await _auth.register(
      email: email,
      password: password,
      name: name,
    );
    _token = session.token;
    _user = session.user;
    await _prefs.setString(_kToken, session.token);
    _safeNotify();
  }

  Future<String?> refreshToken() async {
    final current = _token;
    if (current == null) return null;
    try {
      final session = await _auth.refresh(current);
      _token = session.token;
      _user = session.user;
      await _prefs.setString(_kToken, session.token);
      _safeNotify();
      return session.token;
    } catch (_) {
      await logout();
      return null;
    }
  }

  Future<void> logout() async {
    _user = null;
    _token = null;
    await _prefs.remove(_kToken);
    _safeNotify();
  }

  /// Только для демонстрации границы клиентской защиты (эксперимент).
  void debugOverrideRole(Role role) {
    if (_user == null) return;
    _user = AppUser(
      id: _user!.id,
      email: _user!.email,
      name: _user!.name,
      role: role,
      customerId: _user!.customerId,
    );
    _safeNotify();
  }

  void _safeNotify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
