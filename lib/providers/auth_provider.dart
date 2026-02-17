import 'package:flutter/foundation.dart';
import '../models/user.dart';
import '../services/api_service.dart';

enum AuthStatus { initial, authenticated, unauthenticated, loading }

class AuthProvider extends ChangeNotifier {
  final ApiService _apiService;

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
    _status = isAuth ? AuthStatus.authenticated : AuthStatus.unauthenticated;
    notifyListeners();
  }

  Future<bool> login(String email, String password) async {
    _status = AuthStatus.loading;
    _error = null;
    notifyListeners();

    try {
      _user = await _apiService.login(email, password);
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
    notifyListeners();
  }
}
