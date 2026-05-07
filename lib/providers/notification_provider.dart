import 'dart:convert';
import 'package:flutter/material.dart';
import '../models/app_notification.dart';
import '../services/api_service.dart';
import '../services/connectivity_service.dart';
import '../services/database_service.dart';

class NotificationProvider extends ChangeNotifier {
  final ApiService _apiService;
  final ConnectivityService _connectivityService;
  final DatabaseService _databaseService;

  List<AppNotification> _notifications = [];
  bool _isLoading = false;
  String? _error;

  List<AppNotification> get notifications => _notifications;
  bool get isLoading => _isLoading;
  String? get error => _error;
  int get unreadCount => _notifications.where((n) => !n.isRead).length;

  NotificationProvider({
    required ApiService apiService,
    required ConnectivityService connectivityService,
    required DatabaseService databaseService,
  })  : _apiService = apiService,
        _connectivityService = connectivityService,
        _databaseService = databaseService;

  Future<void> loadNotifications() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    if (!_connectivityService.isConnected) {
      final cached = await _databaseService.getCachedNotifications();
      _notifications = cached.map(_rowToNotification).toList();
      _isLoading = false;
      notifyListeners();
      return;
    }

    try {
      final raw = await _apiService.getNotifications();
      _notifications = raw.map(AppNotification.fromJson).toList();
      await _databaseService.upsertNotifications(
        _notifications.map(_notificationToRow).toList(),
      );
    } on ApiException catch (e) {
      _error = e.message;
      final cached = await _databaseService.getCachedNotifications();
      if (cached.isNotEmpty) {
        _notifications = cached.map(_rowToNotification).toList();
        _error = null;
      }
    } catch (_) {
      final cached = await _databaseService.getCachedNotifications();
      if (cached.isNotEmpty) {
        _notifications = cached.map(_rowToNotification).toList();
      } else {
        _error = 'Failed to load notifications.';
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> markRead(String id) async {
    final index = _notifications.indexWhere((n) => n.id == id);
    if (index != -1 && !_notifications[index].isRead) {
      final n = _notifications[index];
      _notifications[index] = AppNotification(
        id: n.id,
        type: n.type,
        data: n.data,
        readAt: DateTime.now(),
        createdAt: n.createdAt,
      );
      notifyListeners();
      await _databaseService.updateCachedNotificationRead(id);
    }
    if (_connectivityService.isConnected) {
      try {
        await _apiService.markNotificationRead(id);
      } catch (_) {}
    }
  }

  Future<void> markAllRead() async {
    _notifications = _notifications
        .map((n) => AppNotification(
              id: n.id,
              type: n.type,
              data: n.data,
              readAt: n.readAt ?? DateTime.now(),
              createdAt: n.createdAt,
            ))
        .toList();
    notifyListeners();
    await _databaseService.markAllCachedNotificationsRead();
    if (_connectivityService.isConnected) {
      try {
        await _apiService.markAllNotificationsRead();
      } catch (_) {}
    }
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  Map<String, dynamic> _notificationToRow(AppNotification n) => {
        'id': n.id,
        'type': n.type,
        'data': jsonEncode(n.data),
        'read_at': n.readAt?.toIso8601String(),
        'created_at': n.createdAt.toIso8601String(),
      };

  AppNotification _rowToNotification(Map<String, dynamic> r) {
    Map<String, dynamic> data = {};
    try {
      data = jsonDecode(r['data'] as String) as Map<String, dynamic>;
    } catch (_) {}
    return AppNotification(
      id: r['id'] as String,
      type: r['type'] as String,
      data: data,
      readAt: r['read_at'] != null ? DateTime.tryParse(r['read_at'] as String) : null,
      createdAt: DateTime.tryParse(r['created_at'] as String) ?? DateTime.now(),
    );
  }
}
