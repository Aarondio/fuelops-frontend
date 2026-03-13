import 'dart:io';
import 'package:flutter/material.dart';
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
  bool _isLoading = false;
  String? _error;

  List<Pump> get pumps => _pumps;
  List<Reading> get readings => _readings;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isOnline => _connectivityService.isConnected;
  int get pendingCount => _syncService.pendingCount;
  bool get isSyncing => _syncService.isSyncing;

  /// Readings that have opening but no closing yet
  List<Reading> get openReadings =>
      _readings.where((r) => r.isOpen).toList();

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

  void _onSyncChange() {
    notifyListeners();
  }

  void _onConnectivityChange(bool isConnected) {
    notifyListeners();
  }

  Future<void> loadPumps() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      if (isOnline) {
        _pumps = await _apiService.getPumps();
        // Cache the pumps for offline use
        await _databaseService.cachePumps(_pumps.map((p) => <String, dynamic>{
          'id': p.id,
          'station_id': p.stationId,
          'name': p.name,
          'product_type': p.productType,
          'current_price': p.currentPrice,
        }).toList());
      } else {
        final cached = await _databaseService.getCachedPumps();
        _pumps = cached.map((p) => Pump(
          id: p['id'] as int,
          stationId: p['station_id'] as int,
          name: p['name'] as String,
          productType: p['product_type'] as String,
          currentPrice: p['current_price'] as double,
        )).toList();
      }
    } on ApiException catch (e) {
      _error = e.message;
      // Fallback to cache if API fails
      final cached = await _databaseService.getCachedPumps();
      if (cached.isNotEmpty) {
        _pumps = cached.map((p) => Pump(
          id: p['id'] as int,
          stationId: p['station_id'] as int,
          name: p['name'] as String,
          productType: p['product_type'] as String,
          currentPrice: p['current_price'] as double,
        )).toList();
      }
    } catch (e) {
      _error = 'Failed to load pumps. Check your connection.';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadReadings({DateTime? date}) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final targetDate = date ?? DateTime.now();
      if (isOnline) {
        _readings = await _apiService.getReadings(date: targetDate);
        
        // Cache today's readings
        if (DateUtils.isSameDay(targetDate, DateTime.now())) {
          await _databaseService.cacheReadings(_readings.map((r) => <String, dynamic>{
            'id': r.id,
            'pump_id': r.pumpId,
            'pump_name': r.pumpName,
            'opening_reading': r.openingReading,
            'closing_reading': r.closingReading,
            'volume_sold': r.volumeSold,
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
          openingReading: r['opening_reading'] as double,
          closingReading: r['closing_reading'] as double?,
          volumeSold: r['volume_sold'] as double?,
          date: DateTime.parse(r['date'] as String),
          shift: r['shift'] as String,
          status: r['status'] as String,
          createdAt: DateTime.parse(r['created_at'] as String),
        )).toList();
      }
    } on ApiException catch (e) {
      _error = e.message;
      // Fallback to cache
      final cached = await _databaseService.getCachedReadings();
      if (cached.isNotEmpty) {
        _readings = cached.map((r) => Reading(
          id: r['id'] as int,
          pumpId: r['pump_id'] as int,
          pumpName: r['pump_name'] as String?,
          openingReading: r['opening_reading'] as double,
          closingReading: r['closing_reading'] as double?,
          volumeSold: r['volume_sold'] as double?,
          date: DateTime.parse(r['date'] as String),
          shift: r['shift'] as String,
          status: r['status'] as String,
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

  /// Find an open reading for a specific pump today
  Reading? getOpenReadingForPump(int pumpId) {
    try {
      return _readings.firstWhere(
        (r) => r.pumpId == pumpId && r.isOpen,
      );
    } catch (_) {
      return null;
    }
  }

  /// Submit opening reading (creates a new reading, no closing value)
  Future<bool> submitOpeningReading({
    required int pumpId,
    String? pumpName,
    required double openingReading,
    required String shift,
    String? notes,
    File? openingImage,
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
      // If API fails with non-auth error, queue locally
      final queued = await _syncService.queueReading(
        pumpId: pumpId,
        pumpName: pumpName,
        openingReading: openingReading,
        date: DateTime.now(),
        shift: shift,
        notes: notes,
        openingImage: openingImage,
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
      );
      _error = queued ? 'Connection lost. Saved locally.' : 'Connection lost.';
      _isLoading = false;
      notifyListeners();
      return queued;
    }
  }

  /// Submit closing reading (updates an existing open reading)
  Future<bool> submitClosingReading({
    required int readingId,
    required double closingReading,
    String? notes,
    File? closingImage,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    final isConnected = await _connectivityService.checkConnectivity();

    if (!isConnected) {
      // Find the reading details to queue locally
      final Reading? original = _readings.firstWhere((r) => r.id == readingId);
      
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
      final reading = await _apiService.updateReading(
        readingId: readingId,
        closingReading: closingReading,
        notes: notes,
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
      final Reading? original = _readings.firstWhere((r) => r.id == readingId);
      final queued = await _syncService.queueReading(
        pumpId: original!.pumpId,
        pumpName: original.pumpName,
        openingReading: original.openingReading,
        closingReading: closingReading,
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
    } catch (e) {
      final Reading? original = _readings.firstWhere((r) => r.id == readingId);
      final queued = await _syncService.queueReading(
        pumpId: original!.pumpId,
        pumpName: original.pumpName,
        openingReading: original.openingReading,
        closingReading: closingReading,
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
    }
  }

  /// Legacy method kept for offline queue compatibility
  Future<bool> submitReading({
    required int pumpId,
    String? pumpName,
    required double openingReading,
    required double closingReading,
    required String shift,
    String? notes,
    File? openingImage,
    File? closingImage,
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
        closingReading: closingReading,
        date: DateTime.now(),
        shift: shift,
        notes: notes,
        openingImage: openingImage,
        closingImage: closingImage,
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
        closingReading: closingReading,
        date: DateTime.now(),
        shift: shift,
        notes: notes,
      );

      if (openingImage != null) {
        await _apiService.uploadImage(
          file: openingImage,
          category: 'opening_reading',
          uploadableId: reading.id,
          uploadableType: 'App\\Models\\Reading',
        );
      }

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
      await _syncService.queueReading(
        pumpId: pumpId,
        pumpName: pumpName,
        openingReading: openingReading,
        closingReading: closingReading,
        date: DateTime.now(),
        shift: shift,
        notes: notes,
        openingImage: openingImage,
        closingImage: closingImage,
      );
      _error = '${e.message}. Saved locally for later sync.';
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      await _syncService.queueReading(
        pumpId: pumpId,
        pumpName: pumpName,
        openingReading: openingReading,
        closingReading: closingReading,
        date: DateTime.now(),
        shift: shift,
        notes: notes,
        openingImage: openingImage,
        closingImage: closingImage,
      );
      _error = 'Connection lost. Reading saved locally.';
      _isLoading = false;
      notifyListeners();
      return true;
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
