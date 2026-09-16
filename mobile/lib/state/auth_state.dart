import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../services/api_client.dart';

/// Holds the logged-in session (owner or staff). RootGate uses [role] to pick
/// the owner vs staff experience; null role means logged out.
class AuthState extends ChangeNotifier {
  AuthState(this._api);

  final ApiClient _api;
  final _storage = const FlutterSecureStorage();
  static const _key = 'session';

  String? _token;
  String? role; // "owner" | "staff" | "kitchen"
  String? username;
  String? name;
  bool _loading = true;

  bool get loading => _loading;
  bool get isLoggedIn => _token != null;
  bool get isOwner => role == 'owner';
  bool get isStaff => role == 'staff';
  bool get isKitchen => role == 'kitchen';

  Future<void> load() async {
    final raw = await _storage.read(key: _key);
    if (raw != null) {
      final data = jsonDecode(raw) as Map<String, dynamic>;
      _token = data['token'] as String?;
      role = data['role'] as String?;
      username = data['username'] as String?;
      name = data['name'] as String?;
      _api.token = _token;
    }
    _loading = false;
    notifyListeners();
  }

  Future<void> login(String user, String password) async {
    final result = await _api.login(user, password);
    _token = result['token'] as String;
    role = result['role'] as String;
    username = result['username'] as String?;
    name = result['name'] as String?;
    _api.token = _token;
    await _storage.write(
      key: _key,
      value: jsonEncode({
        'token': _token,
        'role': role,
        'username': username,
        'name': name,
      }),
    );
    notifyListeners();
  }

  Future<void> register(String user, String password, String name) async {
    await _api.register(user, password, name);
  }

  Future<void> logout() async {
    _token = null;
    role = null;
    username = null;
    name = null;
    _api.token = null;
    await _storage.delete(key: _key);
    notifyListeners();
  }
}
