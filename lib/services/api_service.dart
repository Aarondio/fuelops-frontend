import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../models/user.dart';
import '../models/pump.dart';
import '../models/reading.dart';
import 'env_config.dart';

class ApiException implements Exception {
  final String message;
  final int? statusCode;
  final bool isAuthError;

  ApiException(this.message, {this.statusCode, this.isAuthError = false});

  @override
  String toString() => message;
}

class AuthExpiredException implements Exception {
  final String message;
  AuthExpiredException([this.message = 'Session expired. Please login again.']);

  @override
  String toString() => message;
}

class ApiService {
  String get _baseUrl => EnvConfig.apiBaseUrl;
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  bool _isRefreshing = false;
  Completer<bool>? _refreshCompleter;

  // Callback to notify when auth expires and refresh fails
  Function()? onAuthExpired;

  Future<String?> get token => _storage.read(key: 'auth_token');

  Future<Map<String, String>> _headers({bool withAuth = true}) async {
    final headers = {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };

    if (withAuth) {
      final authToken = await token;
      if (authToken != null) {
        headers['Authorization'] = 'Bearer $authToken';
      }
    }

    return headers;
  }

  Future<Map<String, dynamic>> _handleResponse(
    http.Response response, {
    bool allowRefresh = true,
  }) async {
    // Handle 401 Unauthorized - try to refresh token
    if (response.statusCode == 401 && allowRefresh) {
      final refreshed = await _refreshToken();
      if (!refreshed) {
        onAuthExpired?.call();
        throw AuthExpiredException();
      }
      // Token was refreshed, but we need to retry the request
      // Throw a special exception to signal retry
      throw _RetryException();
    }

    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (response.body.isEmpty) {
        return {};
      }
      return json.decode(response.body) as Map<String, dynamic>;
    }

    String message = 'An error occurred';
    try {
      final body = json.decode(response.body) as Map<String, dynamic>;
      message = body['message'] as String? ?? message;
    } catch (_) {}

    throw ApiException(
      message,
      statusCode: response.statusCode,
      isAuthError: response.statusCode == 401 || response.statusCode == 403,
    );
  }

  /// Refresh the authentication token
  Future<bool> _refreshToken() async {
    // If already refreshing, wait for the result
    if (_isRefreshing) {
      return _refreshCompleter?.future ?? Future.value(false);
    }

    _isRefreshing = true;
    _refreshCompleter = Completer<bool>();

    try {
      final currentToken = await token;
      if (currentToken == null) {
        _refreshCompleter!.complete(false);
        return false;
      }

      final response = await http.post(
        Uri.parse('$_baseUrl/refresh'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer $currentToken',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        final newToken = data['token'] as String;
        await _storage.write(key: 'auth_token', value: newToken);
        _refreshCompleter!.complete(true);
        return true;
      } else {
        await _storage.delete(key: 'auth_token');
        _refreshCompleter!.complete(false);
        return false;
      }
    } catch (e) {
      _refreshCompleter!.complete(false);
      return false;
    } finally {
      _isRefreshing = false;
      _refreshCompleter = null;
    }
  }

  /// Wrapper for GET requests with automatic token refresh
  Future<http.Response> _get(Uri uri, {int retryCount = 0}) async {
    try {
      final response = await http.get(uri, headers: await _headers());
      await _handleResponse(response); // This will throw _RetryException if refresh needed
      return response;
    } on _RetryException {
      if (retryCount < 1) {
        return _get(uri, retryCount: retryCount + 1);
      }
      rethrow;
    }
  }

  /// Wrapper for POST requests with automatic token refresh
  Future<http.Response> _post(
    Uri uri, {
    Object? body,
    bool withAuth = true,
    int retryCount = 0,
  }) async {
    try {
      final response = await http.post(
        uri,
        headers: await _headers(withAuth: withAuth),
        body: body != null ? json.encode(body) : null,
      );
      await _handleResponse(response); // This will throw _RetryException if refresh needed
      return response;
    } on _RetryException {
      if (retryCount < 1) {
        return _post(uri, body: body, withAuth: withAuth, retryCount: retryCount + 1);
      }
      rethrow;
    }
  }

  Future<http.Response> _put(
    Uri uri, {
    Object? body,
    bool withAuth = true,
    int retryCount = 0,
  }) async {
    try {
      final response = await http.put(
        uri,
        headers: await _headers(withAuth: withAuth),
        body: body != null ? json.encode(body) : null,
      );
      await _handleResponse(response);
      return response;
    } on _RetryException {
      if (retryCount < 1) {
        return _put(uri, body: body, withAuth: withAuth, retryCount: retryCount + 1);
      }
      rethrow;
    }
  }

  // Auth
  Future<User> login(String email, String password) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/login'),
      headers: await _headers(withAuth: false),
      body: json.encode({'email': email, 'password': password}),
    );

    final data = await _handleResponse(response, allowRefresh: false);
    final authToken = data['token'] as String;
    await _storage.write(key: 'auth_token', value: authToken);

    return User.fromJson(data['user'] as Map<String, dynamic>);
  }

  Future<void> logout() async {
    try {
      await http.post(
        Uri.parse('$_baseUrl/logout'),
        headers: await _headers(),
      );
    } finally {
      await _storage.delete(key: 'auth_token');
    }
  }

  Future<bool> isAuthenticated() async {
    final authToken = await token;
    return authToken != null;
  }

  /// Manually refresh the token (can be called proactively)
  Future<bool> refreshToken() async {
    return _refreshToken();
  }

  // Pumps
  Future<List<Pump>> getPumps() async {
    final response = await _get(Uri.parse('$_baseUrl/pumps'));

    final data = await _handleResponse(response, allowRefresh: false);
    final pumps = (data['data'] as List)
        .map((json) => Pump.fromJson(json as Map<String, dynamic>))
        .toList();

    return pumps;
  }

  // Readings
  Future<List<Reading>> getReadings({DateTime? date}) async {
    var uri = Uri.parse('$_baseUrl/readings');
    if (date != null) {
      uri = uri.replace(queryParameters: {
        'date': date.toIso8601String().split('T')[0],
      });
    }

    final response = await _get(uri);

    final data = await _handleResponse(response, allowRefresh: false);
    final readings = (data['data'] as List)
        .map((json) => Reading.fromJson(json as Map<String, dynamic>))
        .toList();

    return readings;
  }

  Future<Reading> createReading({
    required int pumpId,
    required double openingReading,
    double? closingReading,
    required DateTime date,
    required String shift,
    String? notes,
  }) async {
    final body = <String, dynamic>{
      'pumpId': pumpId,
      'openingReading': openingReading,
      'date': date.toIso8601String().split('T')[0],
      'shift': shift,
      'notes': notes,
    };
    if (closingReading != null) {
      body['closingReading'] = closingReading;
    }

    final response = await _post(
      Uri.parse('$_baseUrl/readings'),
      body: body,
    );

    final data = await _handleResponse(response, allowRefresh: false);
    return Reading.fromJson(data['data'] as Map<String, dynamic>);
  }

  Future<Reading> updateReading({
    required int readingId,
    double? closingReading,
    String? notes,
  }) async {
    final body = <String, dynamic>{};
    if (closingReading != null) body['closingReading'] = closingReading;
    if (notes != null) body['notes'] = notes;

    final response = await _put(
      Uri.parse('$_baseUrl/readings/$readingId'),
      body: body,
    );

    final data = await _handleResponse(response, allowRefresh: false);
    return Reading.fromJson(data['data'] as Map<String, dynamic>);
  }

  // Uploads
  Future<Map<String, dynamic>> uploadImage({
    required File file,
    required String category,
    int? uploadableId,
    String? uploadableType,
    int retryCount = 0,
  }) async {
    final uri = Uri.parse('$_baseUrl/uploads');
    final authToken = await token;

    final request = http.MultipartRequest('POST', uri);
    if (authToken != null) {
      request.headers['Authorization'] = 'Bearer $authToken';
    }
    request.headers['Accept'] = 'application/json';

    request.files.add(await http.MultipartFile.fromPath('file', file.path));
    request.fields['category'] = category;

    if (uploadableId != null) {
      request.fields['uploadableId'] = uploadableId.toString();
    }
    if (uploadableType != null) {
      request.fields['uploadableType'] = uploadableType;
    }

    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);

    // Handle 401 with retry
    if (response.statusCode == 401 && retryCount < 1) {
      final refreshed = await _refreshToken();
      if (refreshed) {
        return uploadImage(
          file: file,
          category: category,
          uploadableId: uploadableId,
          uploadableType: uploadableType,
          retryCount: retryCount + 1,
        );
      }
      onAuthExpired?.call();
      throw AuthExpiredException();
    }

    return _handleResponse(response, allowRefresh: false);
  }
}

/// Internal exception to signal that a request should be retried after token refresh
class _RetryException implements Exception {}
