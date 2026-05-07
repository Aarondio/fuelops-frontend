import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../models/attendant.dart';
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
    if (response.statusCode == 401 && allowRefresh) {
      final refreshed = await _refreshToken();
      if (!refreshed) {
        onAuthExpired?.call();
        throw AuthExpiredException();
      }
      throw _RetryException();
    }

    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (response.body.isEmpty) return {};
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

  Future<bool> _refreshToken() async {
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

      final response = await http
          .post(
            Uri.parse('$_baseUrl/refresh'),
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
              'Authorization': 'Bearer $currentToken',
            },
          )
          .timeout(const Duration(seconds: 8));

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

  static const _kTimeout = Duration(seconds: 10);

  Future<http.Response> _get(Uri uri, {int retryCount = 0}) async {
    try {
      final response = await http
          .get(uri, headers: await _headers())
          .timeout(_kTimeout);
      await _handleResponse(response);
      return response;
    } on _RetryException {
      if (retryCount < 1) return _get(uri, retryCount: retryCount + 1);
      rethrow;
    }
  }

  Future<http.Response> _post(
    Uri uri, {
    Object? body,
    bool withAuth = true,
    int retryCount = 0,
  }) async {
    try {
      final response = await http
          .post(
            uri,
            headers: await _headers(withAuth: withAuth),
            body: body != null ? json.encode(body) : null,
          )
          .timeout(_kTimeout);
      await _handleResponse(response);
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
      final response = await http
          .put(
            uri,
            headers: await _headers(withAuth: withAuth),
            body: body != null ? json.encode(body) : null,
          )
          .timeout(_kTimeout);
      await _handleResponse(response);
      return response;
    } on _RetryException {
      if (retryCount < 1) {
        return _put(uri, body: body, withAuth: withAuth, retryCount: retryCount + 1);
      }
      rethrow;
    }
  }

  Future<http.Response> _delete(Uri uri, {int retryCount = 0}) async {
    try {
      final response = await http
          .delete(uri, headers: await _headers())
          .timeout(_kTimeout);
      await _handleResponse(response);
      return response;
    } on _RetryException {
      if (retryCount < 1) return _delete(uri, retryCount: retryCount + 1);
      rethrow;
    }
  }

  // Auth

  Future<User> login(String email, String password) async {
    final response = await http
        .post(
          Uri.parse('$_baseUrl/login'),
          headers: await _headers(withAuth: false),
          body: json.encode({'email': email, 'password': password}),
        )
        .timeout(const Duration(seconds: 10));

    final data = await _handleResponse(response, allowRefresh: false);
    final authToken = data['token'] as String;
    await _storage.write(key: 'auth_token', value: authToken);

    return User.fromJson(data['user'] as Map<String, dynamic>);
  }

  Future<void> logout() async {
    try {
      await http
          .post(Uri.parse('$_baseUrl/logout'), headers: await _headers())
          .timeout(const Duration(seconds: 8));
    } finally {
      await _storage.delete(key: 'auth_token');
    }
  }

  Future<bool> isAuthenticated() async {
    final authToken = await token;
    return authToken != null;
  }

  Future<User> getProfile() async {
    final response = await _get(Uri.parse('$_baseUrl/profile'));
    final data = json.decode(response.body) as Map<String, dynamic>;
    return User.fromJson(data['data'] as Map<String, dynamic>);
  }

  Future<bool> refreshToken() async => _refreshToken();

  // Attendants

  Future<List<Attendant>> getAttendants() async {
    final response = await _get(Uri.parse('$_baseUrl/attendants'));
    final data = json.decode(response.body) as Map<String, dynamic>;
    return (data['data'] as List)
        .map((j) => Attendant.fromJson(j as Map<String, dynamic>))
        .toList();
  }

  // Pumps

  Future<List<Pump>> getPumps() async {
    final response = await _get(Uri.parse('$_baseUrl/pumps'));
    final data = json.decode(response.body) as Map<String, dynamic>;
    return (data['data'] as List)
        .map((j) => Pump.fromJson(j as Map<String, dynamic>))
        .toList();
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
    final data = json.decode(response.body) as Map<String, dynamic>;
    return (data['data'] as List)
        .map((j) => Reading.fromJson(j as Map<String, dynamic>))
        .toList();
  }

  Future<Reading> createReading({
    required int pumpId,
    required double openingReading,
    double? closingReading,
    required DateTime date,
    required String shift,
    String? notes,
    int? attendantId,
    double? ocrConfidence,
  }) async {
    final body = <String, dynamic>{
      'pumpId': pumpId,
      'openingReading': openingReading,
      'date': date.toIso8601String().split('T')[0],
      'shift': shift,
      'notes': notes,
    };
    if (closingReading != null) body['closingReading'] = closingReading;
    if (attendantId != null) body['attendantId'] = attendantId;
    if (ocrConfidence != null) body['ocrConfidence'] = ocrConfidence;

    final response = await _post(Uri.parse('$_baseUrl/readings'), body: body);
    final data = json.decode(response.body) as Map<String, dynamic>;
    return Reading.fromJson(data['data'] as Map<String, dynamic>);
  }

  Future<Reading> updateReading({
    required int readingId,
    double? closingReading,
    String? notes,
    double? ocrConfidence,
  }) async {
    final body = <String, dynamic>{};
    if (closingReading != null) body['closingReading'] = closingReading;
    if (notes != null) body['notes'] = notes;
    if (ocrConfidence != null) body['ocrConfidence'] = ocrConfidence;

    final response = await _put(Uri.parse('$_baseUrl/readings/$readingId'), body: body);
    final data = json.decode(response.body) as Map<String, dynamic>;
    return Reading.fromJson(data['data'] as Map<String, dynamic>);
  }

  Future<Reading> closeReading({
    required int readingId,
    required double closingReading,
    required double declaredLitresSold,
    required double declaredCashCollected,
    String? notes,
    double? ocrConfidence,
    int? attendantId,
  }) async {
    final body = <String, dynamic>{
      'closingReading': closingReading,
      'declaredLitresSold': declaredLitresSold,
      'declaredCashCollected': declaredCashCollected,
    };
    if (notes != null) body['notes'] = notes;
    if (ocrConfidence != null) body['ocrConfidence'] = ocrConfidence;
    if (attendantId != null) body['attendantId'] = attendantId;

    final response = await _post(
      Uri.parse('$_baseUrl/readings/$readingId/close'),
      body: body,
    );
    final data = json.decode(response.body) as Map<String, dynamic>;
    return Reading.fromJson(data['data'] as Map<String, dynamic>);
  }

  Future<Reading> confirmHandover(int readingId) async {
    final response = await _post(
      Uri.parse('$_baseUrl/readings/$readingId/confirm-handover'),
    );
    final data = json.decode(response.body) as Map<String, dynamic>;
    return Reading.fromJson(data['data'] as Map<String, dynamic>);
  }

  // Profile

  Future<void> updateProfile({required String name, required String email}) async {
    await _put(Uri.parse('$_baseUrl/profile'), body: {'name': name, 'email': email});
  }

  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    await _put(Uri.parse('$_baseUrl/profile/password'), body: {
      'current_password': currentPassword,
      'password': newPassword,
      'password_confirmation': newPassword,
    });
  }

  // Device Health

  Future<void> logDeviceHealth({required String eventType, String? message}) async {
    await _post(Uri.parse('$_baseUrl/device-health'), body: {
      'eventType': eventType,
      if (message != null) 'message': message,
    });
  }

  // Dashboard

  Future<Map<String, dynamic>> getDashboardStats() async {
    final response = await _get(Uri.parse('$_baseUrl/dashboard/stats'));
    final data = json.decode(response.body) as Map<String, dynamic>;
    return data['data'] as Map<String, dynamic>;
  }

  // Notifications

  Future<List<Map<String, dynamic>>> getNotifications({bool? unread}) async {
    var uri = Uri.parse('$_baseUrl/notifications');
    if (unread != null) {
      uri = uri.replace(queryParameters: {'unread': unread.toString()});
    }
    final response = await _get(uri);
    final data = json.decode(response.body) as Map<String, dynamic>;
    return ((data['data'] as List?) ?? [])
        .cast<Map<String, dynamic>>();
  }

  Future<void> markNotificationRead(String notificationId) async {
    await _post(Uri.parse('$_baseUrl/notifications/$notificationId/read'));
  }

  Future<void> markAllNotificationsRead() async {
    await _post(Uri.parse('$_baseUrl/notifications/read-all'));
  }

  // Tank Dips

  Future<List<Map<String, dynamic>>> getTankDips({int? tankId}) async {
    var uri = Uri.parse('$_baseUrl/tank-dips');
    if (tankId != null) {
      uri = uri.replace(queryParameters: {'tankId': tankId.toString()});
    }
    final response = await _get(uri);
    final data = json.decode(response.body) as Map<String, dynamic>;
    return ((data['data'] as List?) ?? [])
        .cast<Map<String, dynamic>>();
  }

  Future<Map<String, dynamic>> storeTankDip({
    required int tankId,
    required String date,
    required double openingDip,
    String? notes,
  }) async {
    final response = await _post(Uri.parse('$_baseUrl/tank-dips'), body: {
      'tankId': tankId,
      'date': date,
      'openingDip': openingDip,
      if (notes != null) 'notes': notes,
    });
    final data = json.decode(response.body) as Map<String, dynamic>;
    return data['data'] as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> closeTankDip(
    int tankDipId, {
    required double closingDip,
    String? notes,
  }) async {
    final response = await _post(
      Uri.parse('$_baseUrl/tank-dips/$tankDipId/close'),
      body: {
        'closingDip': closingDip,
        if (notes != null) 'notes': notes,
      },
    );
    final data = json.decode(response.body) as Map<String, dynamic>;
    return data['data'] as Map<String, dynamic>;
  }

  // Deliveries

  Future<List<Map<String, dynamic>>> getDeliveries() async {
    final response = await _get(Uri.parse('$_baseUrl/deliveries'));
    final data = json.decode(response.body) as Map<String, dynamic>;
    return ((data['data'] as List?) ?? [])
        .cast<Map<String, dynamic>>();
  }

  Future<Map<String, dynamic>> storeDelivery({
    required int tankId,
    required String productType,
    required double quantity,
    required double unitPrice,
    required String supplierName,
    String? deliveryNoteNumber,
    String? deliveredAt,
    String? notes,
  }) async {
    final response = await _post(Uri.parse('$_baseUrl/deliveries'), body: {
      'tankId': tankId,
      'productType': productType,
      'quantity': quantity,
      'unitPrice': unitPrice,
      'supplierName': supplierName,
      if (deliveryNoteNumber != null) 'deliveryNoteNumber': deliveryNoteNumber,
      if (deliveredAt != null) 'deliveredAt': deliveredAt,
      if (notes != null) 'notes': notes,
    });
    final data = json.decode(response.body) as Map<String, dynamic>;
    return data['data'] as Map<String, dynamic>;
  }

  // Alert Logs

  Future<List<Map<String, dynamic>>> getAlertLogs() async {
    final response = await _get(Uri.parse('$_baseUrl/alert-logs'));
    final data = json.decode(response.body) as Map<String, dynamic>;
    return ((data['data'] as List?) ?? [])
        .cast<Map<String, dynamic>>();
  }

  // Alert Settings

  Future<Map<String, dynamic>> getAlertSettings() async {
    final response = await _get(Uri.parse('$_baseUrl/settings/alerts'));
    final data = json.decode(response.body) as Map<String, dynamic>;
    return data['data'] as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> updateAlertSettings({
    required bool alertEnabled,
    required double varianceThresholdPercent,
    String? whatsappNumber,
  }) async {
    final response = await _put(Uri.parse('$_baseUrl/settings/alerts'), body: {
      'alertEnabled': alertEnabled,
      'varianceThresholdPercent': varianceThresholdPercent,
      if (whatsappNumber != null && whatsappNumber.isNotEmpty)
        'whatsappNumber': whatsappNumber,
    });
    final data = json.decode(response.body) as Map<String, dynamic>;
    return data['data'] as Map<String, dynamic>;
  }

  // Tanks

  Future<List<Map<String, dynamic>>> getTanks() async {
    final response = await _get(Uri.parse('$_baseUrl/tanks'));
    final data = json.decode(response.body) as Map<String, dynamic>;
    return ((data['data'] as List?) ?? [])
        .cast<Map<String, dynamic>>();
  }

  // Preview Close Reading

  Future<Map<String, dynamic>> previewCloseReading({
    required int readingId,
    required double closingReading,
    required double declaredLitresSold,
    required double declaredCashCollected,
  }) async {
    final response = await _post(
      Uri.parse('$_baseUrl/readings/$readingId/preview-close'),
      body: {
        'closingReading': closingReading,
        'declaredLitresSold': declaredLitresSold,
        'declaredCashCollected': declaredCashCollected,
      },
    );
    final data = json.decode(response.body) as Map<String, dynamic>;
    return data['data'] as Map<String, dynamic>;
  }

  // Wholesale Customers

  Future<List<Map<String, dynamic>>> getWholesaleCustomers({
    String? status,
    String? search,
  }) async {
    final params = <String, String>{};
    if (status != null) params['status'] = status;
    if (search != null && search.isNotEmpty) params['search'] = search;
    final uri = Uri.parse('$_baseUrl/wholesale/customers').replace(queryParameters: params.isEmpty ? null : params);
    final response = await _get(uri);
    final data = json.decode(response.body) as Map<String, dynamic>;
    return ((data['data'] as List?) ?? []).cast<Map<String, dynamic>>();
  }

  Future<Map<String, dynamic>> createWholesaleCustomer({
    required String name,
    String? companyName,
    String? phone,
    String? email,
    String? address,
    required double creditLimit,
    String status = 'active',
    String? notes,
  }) async {
    final response = await _post(Uri.parse('$_baseUrl/wholesale/customers'), body: {
      'name': name,
      if (companyName != null && companyName.isNotEmpty) 'companyName': companyName,
      if (phone != null && phone.isNotEmpty) 'phone': phone,
      if (email != null && email.isNotEmpty) 'email': email,
      if (address != null && address.isNotEmpty) 'address': address,
      'creditLimit': creditLimit,
      'status': status,
      if (notes != null && notes.isNotEmpty) 'notes': notes,
    });
    final data = json.decode(response.body) as Map<String, dynamic>;
    return data['data'] as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> updateWholesaleCustomer(
    int id, {
    String? name,
    String? companyName,
    String? phone,
    String? email,
    String? address,
    double? creditLimit,
    String? status,
    String? notes,
  }) async {
    final response = await _put(Uri.parse('$_baseUrl/wholesale/customers/$id'), body: {
      if (name != null) 'name': name,
      if (companyName != null) 'companyName': companyName,
      if (phone != null) 'phone': phone,
      if (email != null) 'email': email,
      if (address != null) 'address': address,
      if (creditLimit != null) 'creditLimit': creditLimit,
      if (status != null) 'status': status,
      if (notes != null) 'notes': notes,
    });
    final data = json.decode(response.body) as Map<String, dynamic>;
    return data['data'] as Map<String, dynamic>;
  }

  Future<void> deleteWholesaleCustomer(int id) async {
    await _delete(Uri.parse('$_baseUrl/wholesale/customers/$id'));
  }

  // Wholesale Transactions

  Future<List<Map<String, dynamic>>> getWholesaleTransactions({
    int? customerId,
    String? productType,
    String? paymentStatus,
    String? from,
    String? to,
  }) async {
    final params = <String, String>{};
    if (customerId != null) params['customerId'] = customerId.toString();
    if (productType != null) params['productType'] = productType;
    if (paymentStatus != null) params['paymentStatus'] = paymentStatus;
    if (from != null) params['from'] = from;
    if (to != null) params['to'] = to;
    final uri = Uri.parse('$_baseUrl/wholesale/transactions').replace(queryParameters: params.isEmpty ? null : params);
    final response = await _get(uri);
    final data = json.decode(response.body) as Map<String, dynamic>;
    return ((data['data'] as List?) ?? []).cast<Map<String, dynamic>>();
  }

  Future<Map<String, dynamic>> createWholesaleTransaction({
    required int wholesaleCustomerId,
    required String productType,
    required double quantity,
    required double unitPrice,
    required String paymentStatus,
    double? amountPaid,
    String? notes,
  }) async {
    final response = await _post(Uri.parse('$_baseUrl/wholesale/transactions'), body: {
      'wholesaleCustomerId': wholesaleCustomerId,
      'productType': productType,
      'quantity': quantity,
      'unitPrice': unitPrice,
      'paymentStatus': paymentStatus,
      if (amountPaid != null) 'amountPaid': amountPaid,
      if (notes != null && notes.isNotEmpty) 'notes': notes,
    });
    final data = json.decode(response.body) as Map<String, dynamic>;
    return data['data'] as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> updateWholesaleTransaction(
    int id, {
    String? paymentStatus,
    double? amountPaid,
    String? notes,
  }) async {
    final response = await _put(Uri.parse('$_baseUrl/wholesale/transactions/$id'), body: {
      if (paymentStatus != null) 'paymentStatus': paymentStatus,
      if (amountPaid != null) 'amountPaid': amountPaid,
      if (notes != null) 'notes': notes,
    });
    final data = json.decode(response.body) as Map<String, dynamic>;
    return data['data'] as Map<String, dynamic>;
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
    if (uploadableId != null) request.fields['uploadableId'] = uploadableId.toString();
    if (uploadableType != null) request.fields['uploadableType'] = uploadableType;

    final streamedResponse =
        await request.send().timeout(const Duration(seconds: 30));
    final response = await http.Response.fromStream(streamedResponse);

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

class _RetryException implements Exception {}
