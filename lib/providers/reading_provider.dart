import 'dart:io';
import 'package:flutter/material.dart';
import '../models/attendant.dart';
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
  bool _isLoading = false;
  String? _error;

  List<Pump> get pumps => _pumps;
  List<Reading> get readings => _readings;
  List<Attendant> get attendants => _attendants;
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
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadAttendants() async {
    if (!isOnline) return;
    try {
      _attendants = await _apiService.getAttendants();
      notifyListeners();
    } catch (_) {}
  }

  Future<void> loadReadings({DateTime? date}) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final targetDate = date ?? DateTime.now();
      if (isOnline) {
        _readings = await _apiService.getReadings(date: targetDate);

        if (DateUtils.isSameDay(targetDate, DateTime.now())) {
          await _databaseService.cacheReadings(_readings.map((r) => <String, dynamic>{
            'id': r.id,
            'pump_id': r.pumpId,
            'pump_name': r.pumpName,
            'attendant_id': r.attendantId,
            'opening_reading': r.openingReading,
            'closing_reading': r.closingReading,
            'volume_sold': r.volumeSold,
            'variance_status': r.varianceStatus,
            'revenue_variance': r.revenueVariance,
            'handover_confirmed_at': r.handoverConfirmedAt?.toIso8601String(),
            'date': r.date.toIso8601String().split('T')[0],
            'shift': r.shift,
            'status': r.status,
            'created_at': r.createdAt.toIso8601String(),
          }).toList());
        }
      } else {
        final cached = await _databaseService.getCachedReadings();
        _readings = cached.map((r) => Reading(
          id: r['id'] as int,
          pumpId: r['pump_id'] as int,
          pumpName: r['pump_name'] as String?,
          attendantId: r['attendant_id'] as int?,
          openingReading: (r['opening_reading'] as num).toDouble(),
          closingReading: r['closing_reading'] != null
              ? (r['closing_reading'] as num).toDouble()
              : null,
          volumeSold: r['volume_sold'] != null
              ? (r['volume_sold'] as num).toDouble()
              : null,
          varianceStatus: r['variance_status'] as String?,
          revenueVariance: r['revenue_variance'] != null
              ? (r['revenue_variance'] as num).toDouble()
              : null,
          handoverConfirmedAt: r['handover_confirmed_at'] != null
              ? DateTime.parse(r['handover_confirmed_at'] as String)
              : null,
          date: DateTime.parse(r['date'] as String),
          shift: r['shift'] as String,
          status: r['status'] as String? ?? 'open',
          createdAt: DateTime.parse(r['created_at'] as String),
        )).toList();
      }
    } on ApiException catch (e) {
      _error = e.message;
      final cached = await _databaseService.getCachedReadings();
      if (cached.isNotEmpty) {
        _readings = cached.map((r) => Reading(
          id: r['id'] as int,
          pumpId: r['pump_id'] as int,
          pumpName: r['pump_name'] as String?,
          openingReading: (r['opening_reading'] as num).toDouble(),
          closingReading: r['closing_reading'] != null
              ? (r['closing_reading'] as num).toDouble()
              : null,
          volumeSold: r['volume_sold'] != null
              ? (r['volume_sold'] as num).toDouble()
              : null,
          varianceStatus: r['variance_status'] as String?,
          date: DateTime.parse(r['date'] as String),
          shift: r['shift'] as String,
          status: r['status'] as String? ?? 'open',
          createdAt: DateTime.parse(r['created_at'] as String),
        )).toList();
      }
    } catch (e) {
      _error = 'Failed to load readings. Check your connection.';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

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

    final isConnected = await _connectivityService.checkConnectivity();

    if (!isConnected) {
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
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    final isConnected = await _connectivityService.checkConnectivity();

    if (!isConnected) {
      final Reading? original = _readings.firstWhere(
        (r) => r.id == readingId,
        orElse: () => throw StateError('Reading not found'),
      );

      if (original == null) {
        _error = 'Could not find original reading details.';
        _isLoading = false;
        notifyListeners();
        return false;
      }

      final queued = await _syncService.queueReading(
        pumpId: original.pumpId,
        pumpName: original.pumpName,
        openingReading: original.openingReading,
        closingReading: closingReading,
        declaredLitresSold: declaredLitresSold,
        declaredCashCollected: declaredCashCollected,
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
      final Reading? original = _readings.firstWhere(
        (r) => r.id == readingId,
        orElse: () => throw StateError('Reading not found'),
      );
      if (original != null) {
        final queued = await _syncService.queueReading(
          pumpId: original.pumpId,
          pumpName: original.pumpName,
          openingReading: original.openingReading,
          closingReading: closingReading,
          declaredLitresSold: declaredLitresSold,
          declaredCashCollected: declaredCashCollected,
          ocrConfidence: ocrConfidence,
          date: DateTime.now(),
          shift: original.shift,
          notes: notes,
          closingImage: closingImage,
          serverId: readingId,
          isClosingOnly: true,
        );
        _error = queued ? '${e.message}. Saved locally for later sync.' : e.message;
      } else {
        _error = e.message;
      }
      _isLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      _error = 'Connection lost.';
      _isLoading = false;
      notifyListeners();
      return false;
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
