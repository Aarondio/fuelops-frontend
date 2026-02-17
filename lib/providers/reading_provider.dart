import 'dart:io';
import 'package:flutter/foundation.dart';
import '../models/pump.dart';
import '../models/reading.dart';
import '../services/api_service.dart';
import '../services/sync_service.dart';
import '../services/connectivity_service.dart';

class ReadingProvider extends ChangeNotifier {
  final ApiService _apiService;
  final SyncService _syncService;
  final ConnectivityService _connectivityService;

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
  })  : _apiService = apiService,
        _syncService = syncService,
        _connectivityService = connectivityService {
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
      _pumps = await _apiService.getPumps();
    } on ApiException catch (e) {
      _error = e.message;
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
      _readings = await _apiService.getReadings(date: date ?? DateTime.now());
    } on ApiException catch (e) {
      _error = e.message;
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
        closingReading: 0, // placeholder for offline queue
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
      _error = '${e.message}. Saved locally for later sync.';
      _isLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      _error = 'Connection lost. Please try again.';
      _isLoading = false;
      notifyListeners();
      return false;
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
      _error = e.message;
      _isLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      _error = 'Connection lost. Please try again.';
      _isLoading = false;
      notifyListeners();
      return false;
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
