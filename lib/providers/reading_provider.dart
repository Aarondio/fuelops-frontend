import 'dart:io';
import 'package:flutter/material.dart';
import '../models/attendant.dart';
import '../models/dashboard_stats.dart';
import '../models/pump.dart';
import '../models/reading.dart';
import '../services/api_service.dart';
import '../services/sync_service.dart';
import '../services/connectivity_service.dart';
import '../services/database_service.dart';

class ReadingProvider extends ChangeNotifier {
  final ApiService _apiService;
  final SyncService _syncService;
  final ConnectivityService _connectivityService;
  final DatabaseService _databaseService;

  List<Pump> _pumps = [];
  List<Reading> _readings = [];
  List<Attendant> _attendants = [];
  DashboardStats? _dashboardStats;
  bool _isLoading = false;
  bool _isPrefetching = false;
  String? _error;

  List<Pump> get pumps => _pumps;
  List<Reading> get readings => _readings;
  List<Attendant> get attendants => _attendants;
  DashboardStats? get dashboardStats => _dashboardStats;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isOnline => _connectivityService.isConnected;
  int get pendingCount => _syncService.pendingCount;
  bool get isSyncing => _syncService.isSyncing;

  List<Reading> get openReadings => _readings.where((r) => r.isOpen).toList();

  ReadingProvider({
    required ApiService apiService,
    required SyncService syncService,
    required ConnectivityService connectivityService,
    required DatabaseService databaseService,
  })  : _apiService = apiService,
        _syncService = syncService,
        _connectivityService = connectivityService,
        _databaseService = databaseService {
    _syncService.addListener(_onSyncChange);
    _connectivityService.connectionStatus.listen(_onConnectivityChange);
  }

  void _onSyncChange() => notifyListeners();
  void _onConnectivityChange(bool isConnected) => notifyListeners();

  Future<void> loadPumps() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      if (isOnline) {
        _pumps = await _apiService.getPumps();
        await _databaseService.cachePumps(_pumps.map((p) => <String, dynamic>{
          'id': p.id,
          'name': p.name,
          'product_type': p.productType,
          'current_price': p.currentPrice,
        }).toList());
      } else {
        final cached = await _databaseService.getCachedPumps();
        _pumps = cached.map((p) => Pump(
          id: p['id'] as int,
          stationId: p['station_id'] as int? ?? 0,
          name: p['name'] as String,
          productType: p['product_type'] as String,
          currentPrice: (p['current_price'] as num).toDouble(),
        )).toList();
      }
    } on ApiException catch (e) {
      _error = e.message;
      final cached = await _databaseService.getCachedPumps();
      if (cached.isNotEmpty) {
        _pumps = cached.map((p) => Pump(
          id: p['id'] as int,
          stationId: p['station_id'] as int? ?? 0,
          name: p['name'] as String,
          productType: p['product_type'] as String,
          currentPrice: (p['current_price'] as num).toDouble(),
        )).toList();
      }
    } catch (e) {
      _error = 'Failed to load pumps. Check your connection.';
      // Non-API error (SocketException etc) — still try cache
      final cached = await _databaseService.getCachedPumps();
      if (cached.isNotEmpty) {
        _pumps = cached.map((p) => Pump(
          id: p['id'] as int,
          stationId: p['station_id'] as int? ?? 0,
          name: p['name'] as String,
          productType: p['product_type'] as String,
          currentPrice: (p['current_price'] as num).toDouble(),
        )).toList();
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadAttendants() async {
    if (!isOnline) {
      final cached = await _databaseService.getCachedAttendants();
      if (cached.isNotEmpty) {
        _attendants = cached
            .map((r) => Attendant(
                  id: r['id'] as int,
                  stationId: r['station_id'] as int,
                  name: r['name'] as String,
                  phone: r['phone'] as String?,
                  isActive: (r['is_active'] as int) == 1,
                ))
            .toList();
        notifyListeners();
      }
      return;
    }
    try {
      _attendants = await _apiService.getAttendants();
      await _databaseService.replaceAllAttendants(
        _attendants
            .map((a) => {
                  'id': a.id,
                  'station_id': a.stationId,
                  'name': a.name,
                  'phone': a.phone,
                  'is_active': a.isActive ? 1 : 0,
                })
            .toList(),
      );
      notifyListeners();
    } catch (_) {
      // Fall back to cached on API failure
      final cached = await _databaseService.getCachedAttendants();
      if (cached.isNotEmpty) {
        _attendants = cached
            .map((r) => Attendant(
                  id: r['id'] as int,
                  stationId: r['station_id'] as int,
                  name: r['name'] as String,
                  phone: r['phone'] as String?,
                  isActive: (r['is_active'] as int) == 1,
                ))
            .toList();
        notifyListeners();
      }
    }
  }

  Future<void> loadDashboardStats() async {
    if (!isOnline) return;
    try {
      final raw = await _apiService.getDashboardStats();
      _dashboardStats = DashboardStats.fromJson(raw);
      notifyListeners();
    } catch (_) {}
  }

  Future<void> loadReadings({DateTime? date}) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    final targetDate = date ?? DateTime.now();
    final dateStr = targetDate.toIso8601String().split('T')[0];

    try {
      if (isOnline) {
        _readings = await _apiService.getReadings(date: targetDate);
        // Upsert into cache — accumulates across all dates
        await _databaseService.upsertReadings(_readings.map((r) => _readingToRow(r)).toList());
      } else {
        final cached = await _databaseService.getCachedReadingsForDate(dateStr);
        _readings = cached.map((r) => _rowToReading(r)).toList();
      }
    } on ApiException catch (e) {
      _error = e.message;
      final cached = await _databaseService.getCachedReadingsForDate(dateStr);
      _readings = cached.map((r) => _rowToReading(r)).toList();
    } catch (_) {
      _error = 'Failed to load readings. Check your connection.';
      final cached = await _databaseService.getCachedReadingsForDate(dateStr);
      if (cached.isNotEmpty) {
        _readings = cached.map(_rowToReading).toList();
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Silently prefetches last [days] days in background — no loading state.
  /// Called once after authentication to seed the offline cache.
  /// Guard: concurrent calls are no-ops; individual day failures skip, not abort.
  Future<void> prefetchRecentDays({int days = 7}) async {
    if (!isOnline || _isPrefetching) return;
    _isPrefetching = true;
    try {
      final cachedDates = await _databaseService.getCachedDates();
      for (var i = 1; i <= days; i++) {
        if (!isOnline) break; // abort if connection drops mid-loop
        final date = DateTime.now().subtract(Duration(days: i));
        final dateStr = date.toIso8601String().split('T')[0];
        if (cachedDates.contains(dateStr)) continue; // already cached, skip
        try {
          final readings = await _apiService.getReadings(date: date);
          if (readings.isNotEmpty) {
            await _databaseService.upsertReadings(readings.map(_readingToRow).toList());
          }
          await Future.delayed(const Duration(milliseconds: 300)); // rate limit
        } catch (_) {
          continue; // skip this day, try the next
        }
      }
    } finally {
      _isPrefetching = false;
    }
  }

  Map<String, dynamic> _readingToRow(Reading r) => {
    'id': r.id,
    'pump_id': r.pumpId,
    'pump_name': r.pumpName,
    'attendant_id': r.attendantId,
    'opening_reading': r.openingReading,
    'closing_reading': r.closingReading,
    'volume_sold': r.volumeSold,
    'declared_litres_sold': r.declaredLitresSold,
    'declared_cash_collected': r.declaredCashCollected,
    'price_at_close': r.priceAtClose,
    'expected_revenue': r.expectedRevenue,
    'volume_variance': r.volumeVariance,
    'revenue_variance': r.revenueVariance,
    'variance_status': r.varianceStatus,
    'handover_confirmed_at': r.handoverConfirmedAt?.toIso8601String(),
    'closed_at': r.closedAt?.toIso8601String(),
    'date': r.date.toIso8601String().split('T')[0],
    'shift': r.shift,
    'status': r.status,
    'notes': r.notes,
    'ocr_confidence': r.ocrConfidence,
    'low_confidence_flag': r.lowConfidenceFlag ? 1 : 0,
    'created_at': r.createdAt.toIso8601String(),
  };

  Reading _rowToReading(Map<String, dynamic> r) => Reading(
    id: r['id'] as int,
    pumpId: r['pump_id'] as int,
    pumpName: r['pump_name'] as String?,
    attendantId: r['attendant_id'] as int?,
    openingReading: (r['opening_reading'] as num).toDouble(),
    closingReading: r['closing_reading'] != null ? (r['closing_reading'] as num).toDouble() : null,
    volumeSold: r['volume_sold'] != null ? (r['volume_sold'] as num).toDouble() : null,
    declaredLitresSold: r['declared_litres_sold'] != null ? (r['declared_litres_sold'] as num).toDouble() : null,
    declaredCashCollected: r['declared_cash_collected'] != null ? (r['declared_cash_collected'] as num).toDouble() : null,
    priceAtClose: r['price_at_close'] != null ? (r['price_at_close'] as num).toDouble() : null,
    expectedRevenue: r['expected_revenue'] != null ? (r['expected_revenue'] as num).toDouble() : null,
    volumeVariance: r['volume_variance'] != null ? (r['volume_variance'] as num).toDouble() : null,
    revenueVariance: r['revenue_variance'] != null ? (r['revenue_variance'] as num).toDouble() : null,
    varianceStatus: r['variance_status'] as String?,
    handoverConfirmedAt: r['handover_confirmed_at'] != null ? DateTime.tryParse(r['handover_confirmed_at'] as String) : null,
    closedAt: r['closed_at'] != null ? DateTime.tryParse(r['closed_at'] as String) : null,
    date: r['date'] != null
        ? DateTime.tryParse(r['date'] as String) ?? DateTime.now()
        : DateTime.now(),
    shift: r['shift'] as String? ?? 'day',
    status: r['status'] as String? ?? 'open',
    notes: r['notes'] as String?,
    ocrConfidence: r['ocr_confidence'] != null ? (r['ocr_confidence'] as num).toDouble() : null,
    lowConfidenceFlag: (r['low_confidence_flag'] as int? ?? 0) == 1,
    createdAt: r['created_at'] != null
        ? DateTime.tryParse(r['created_at'] as String) ?? DateTime.now()
        : DateTime.now(),
  );

  Reading? getOpenReadingForPump(int pumpId) {
    try {
      return _readings.firstWhere((r) => r.pumpId == pumpId && r.isOpen);
    } catch (_) {
      return null;
    }
  }

  Future<bool> submitOpeningReading({
    required int pumpId,
    String? pumpName,
    required double openingReading,
    required String shift,
    String? notes,
    File? openingImage,
    int? attendantId,
    double? ocrConfidence,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    // Use cached isOnline — avoids 5s DNS probe on every submit.
    // If stale, the API call will fail and the catch block queues anyway.
    if (!isOnline) {
      final queued = await _syncService.queueReading(
        pumpId: pumpId,
        pumpName: pumpName,
        openingReading: openingReading,
        date: DateTime.now(),
        shift: shift,
        notes: notes,
        openingImage: openingImage,
        attendantId: attendantId,
        ocrConfidence: ocrConfidence,
      );
      _isLoading = false;
      _error = queued ? null : 'Failed to save reading locally';
      notifyListeners();
      return queued;
    }

    try {
      final reading = await _apiService.createReading(
        pumpId: pumpId,
        openingReading: openingReading,
        date: DateTime.now(),
        shift: shift,
        notes: notes,
        attendantId: attendantId,
        ocrConfidence: ocrConfidence,
      );

      if (openingImage != null) {
        await _apiService.uploadImage(
          file: openingImage,
          category: 'opening_reading',
          uploadableId: reading.id,
          uploadableType: 'App\\Models\\Reading',
        );
      }

      await loadReadings();
      return true;
    } on ApiException catch (e) {
      final queued = await _syncService.queueReading(
        pumpId: pumpId,
        pumpName: pumpName,
        openingReading: openingReading,
        date: DateTime.now(),
        shift: shift,
        notes: notes,
        openingImage: openingImage,
        attendantId: attendantId,
        ocrConfidence: ocrConfidence,
      );
      _error = queued ? '${e.message}. Saved locally for later sync.' : e.message;
      _isLoading = false;
      notifyListeners();
      return queued;
    } catch (e) {
      final queued = await _syncService.queueReading(
        pumpId: pumpId,
        pumpName: pumpName,
        openingReading: openingReading,
        date: DateTime.now(),
        shift: shift,
        notes: notes,
        openingImage: openingImage,
        attendantId: attendantId,
        ocrConfidence: ocrConfidence,
      );
      _error = queued ? 'Connection lost. Saved locally.' : 'Connection lost.';
      _isLoading = false;
      notifyListeners();
      return queued;
    }
  }

  Future<bool> submitClosingReading({
    required int readingId,
    required double closingReading,
    required double declaredLitresSold,
    required double declaredCashCollected,
    String? notes,
    File? closingImage,
    double? ocrConfidence,
    int? attendantId,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    // Use cached isOnline — avoids 5s DNS probe on every submit.
    if (!isOnline) {
      Reading original;
      try {
        // Try in-memory list first; fall back to cached readings DB if empty
        original = _readings.firstWhere((r) => r.id == readingId);
      } catch (_) {
        // Last-resort: search cached DB
        try {
          final cachedRows = await _databaseService.getCachedReadings();
          final row = cachedRows.firstWhere(
            (r) => r['id'] == readingId,
            orElse: () => throw StateError('not found'),
          );
          original = _rowToReading(row);
        } catch (_) {
          _error = 'Could not find reading — please reopen the app.';
          _isLoading = false;
          notifyListeners();
          return false;
        }
      }

      final queued = await _syncService.queueReading(
        pumpId: original.pumpId,
        pumpName: original.pumpName,
        openingReading: original.openingReading,
        closingReading: closingReading,
        declaredLitresSold: declaredLitresSold,
        declaredCashCollected: declaredCashCollected,
        attendantId: attendantId,
        ocrConfidence: ocrConfidence,
        date: DateTime.now(),
        shift: original.shift,
        notes: notes,
        closingImage: closingImage,
        serverId: readingId,
        isClosingOnly: true,
      );

      _isLoading = false;
      _error = queued ? null : 'Failed to save reading locally';
      notifyListeners();
      return queued;
    }

    try {
      final reading = await _apiService.closeReading(
        readingId: readingId,
        closingReading: closingReading,
        declaredLitresSold: declaredLitresSold,
        declaredCashCollected: declaredCashCollected,
        notes: notes,
        ocrConfidence: ocrConfidence,
        attendantId: attendantId,
      );

      if (closingImage != null) {
        await _apiService.uploadImage(
          file: closingImage,
          category: 'closing_reading',
          uploadableId: reading.id,
          uploadableType: 'App\\Models\\Reading',
        );
      }

      await loadReadings();
      return true;
    } on ApiException catch (e) {
      // API-level failure — queue for later sync and return queued result
      try {
        final Reading original = _readings.firstWhere((r) => r.id == readingId);
        final queued = await _syncService.queueReading(
          pumpId: original.pumpId,
          pumpName: original.pumpName,
          openingReading: original.openingReading,
          closingReading: closingReading,
          declaredLitresSold: declaredLitresSold,
          declaredCashCollected: declaredCashCollected,
          attendantId: attendantId,
          ocrConfidence: ocrConfidence,
          date: DateTime.now(),
          shift: original.shift,
          notes: notes,
          closingImage: closingImage,
          serverId: readingId,
          isClosingOnly: true,
        );
        _error = queued ? '${e.message}. Saved locally for later sync.' : e.message;
        _isLoading = false;
        notifyListeners();
        return queued;
      } catch (_) {
        _error = e.message;
        _isLoading = false;
        notifyListeners();
        return false;
      }
    } catch (e) {
      // Connection-level failure (SocketException etc) — also queue, don't lose data
      try {
        final Reading original = _readings.firstWhere((r) => r.id == readingId);
        final queued = await _syncService.queueReading(
          pumpId: original.pumpId,
          pumpName: original.pumpName,
          openingReading: original.openingReading,
          closingReading: closingReading,
          declaredLitresSold: declaredLitresSold,
          declaredCashCollected: declaredCashCollected,
          attendantId: attendantId,
          ocrConfidence: ocrConfidence,
          date: DateTime.now(),
          shift: original.shift,
          notes: notes,
          closingImage: closingImage,
          serverId: readingId,
          isClosingOnly: true,
        );
        _error = queued ? 'Connection lost. Saved locally.' : 'Connection lost.';
        _isLoading = false;
        notifyListeners();
        return queued;
      } catch (_) {
        _error = 'Connection lost.';
        _isLoading = false;
        notifyListeners();
        return false;
      }
    }
  }

  Future<bool> confirmHandover(int readingId) async {
    try {
      await _apiService.confirmHandover(readingId);
      await loadReadings();
      return true;
    } on ApiException catch (e) {
      _error = e.message;
      notifyListeners();
      return false;
    } catch (e) {
      _error = 'Failed to confirm handover.';
      notifyListeners();
      return false;
    }
  }

  Future<void> syncNow() async {
    await _syncService.syncPendingReadings();
    await loadReadings();
  }

  Future<void> retryFailedSync() async {
    await _syncService.retryFailed();
  }

  Future<List<Map<String, dynamic>>> getPendingReadings() async {
    return await _syncService.getPendingReadings();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _syncService.removeListener(_onSyncChange);
    super.dispose();
  }
}
