import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../models/user.dart';
import '../services/api_service.dart';

enum AuthStatus { initial, authenticated, unauthenticated, loading }

class AuthProvider extends ChangeNotifier {
  final ApiService _apiService;
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  AuthStatus _status = AuthStatus.initial;
  User? _user;
  String? _error;
  String? _sessionExpiredMessage;

  AuthProvider({required ApiService apiService}) : _apiService = apiService;

  AuthStatus get status => _status;
  User? get user => _user;
  String? get error => _error;
  String? get sessionExpiredMessage => _sessionExpiredMessage;
  bool get isAuthenticated => _status == AuthStatus.authenticated;

  Future<void> checkAuth() async {
    final isAuth = await _apiService.isAuthenticated();
    if (!isAuth) {
      _status = AuthStatus.unauthenticated;
      notifyListeners();
      return;
    }

    // Restore cached user data immediately
    await _restoreUser();
    _status = AuthStatus.authenticated;
    notifyListeners();

    // Validate token and refresh user data in background
    try {
      _user = await _apiService.getProfile();
      await _persistUser(_user!);
      notifyListeners();
    } on AuthExpiredException {
      handleAuthExpired();
    } catch (_) {
      // Keep cached user data if profile fetch fails (offline etc.)
    }
  }

  Future<bool> login(String email, String password) async {
    _status = AuthStatus.loading;
    _error = null;
    _sessionExpiredMessage = null;
    notifyListeners();

    try {
      _user = await _apiService.login(email, password);
      await _persistUser(_user!);
      _status = AuthStatus.authenticated;
      notifyListeners();
      return true;
    } on ApiException catch (e) {
      _error = e.message;
      _status = AuthStatus.unauthenticated;
      notifyListeners();
      return false;
    } catch (e) {
      _error = 'Connection failed. Please check your network.';
      _status = AuthStatus.unauthenticated;
      notifyListeners();
      return false;
    }
  }

  Future<void> logout() async {
    try {
      await _apiService.logout();
    } finally {
      _user = null;
      await _storage.delete(key: 'auth_user');
      _status = AuthStatus.unauthenticated;
      notifyListeners();
    }
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  void clearSessionExpiredMessage() {
    _sessionExpiredMessage = null;
    notifyListeners();
  }

  /// Called when the auth token expires and cannot be refreshed
  void handleAuthExpired() {
    _user = null;
    _status = AuthStatus.unauthenticated;
    _sessionExpiredMessage = 'Your session has expired. Please login again.';
    _storage.delete(key: 'auth_user');
    notifyListeners();
  }

  Future<void> _persistUser(User user) async {
    final userJson = json.encode({
      'id': user.id,
      'name': user.name,
      'email': user.email,
      'role': user.role,
      'stationId': user.stationId,
      'stationName': user.stationName,
    });
    await _storage.write(key: 'auth_user', value: userJson);
  }

  Future<void> _restoreUser() async {
    final userJson = await _storage.read(key: 'auth_user');
    if (userJson != null) {
      try {
        final data = json.decode(userJson) as Map<String, dynamic>;
        _user = User(
          id: data['id'] as int,
          name: data['name'] as String,
          email: data['email'] as String,
          role: data['role'] as String,
          stationId: data['stationId'] as int?,
          stationName: data['stationName'] as String?,
        );
      } catch (_) {
        // Corrupted cache, ignore
      }
    }
  }
}
