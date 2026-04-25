import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'api_service.dart';
import 'database_service.dart';
import 'connectivity_service.dart';

class SyncService extends ChangeNotifier {
  final ApiService _apiService;
  final DatabaseService _databaseService;
  final ConnectivityService _connectivityService;

  bool _isSyncing = false;
  int _pendingCount = 0;
  String? _lastError;
  StreamSubscription? _connectivitySubscription;

  bool get isSyncing => _isSyncing;
  int get pendingCount => _pendingCount;
  String? get lastError => _lastError;
  bool get hasPending => _pendingCount > 0;

  SyncService({
    required ApiService apiService,
    required DatabaseService databaseService,
    required ConnectivityService connectivityService,
  })  : _apiService = apiService,
        _databaseService = databaseService,
        _connectivityService = connectivityService {
    _init();
  }

  void _init() {
    _updatePendingCount();
    _connectivitySubscription =
        _connectivityService.connectionStatus.listen((isConnected) {
      if (isConnected) syncPendingReadings();
    });
  }

  Future<void> _updatePendingCount() async {
    _pendingCount = await _databaseService.getPendingCount();
    notifyListeners();
  }

  Future<bool> queueReading({
    required int pumpId,
    String? pumpName,
    required double openingReading,
    double? closingReading,
    double? declaredLitresSold,
    double? declaredCashCollected,
    int? attendantId,
    double? ocrConfidence,
    required DateTime date,
    required String shift,
    String? notes,
    File? openingImage,
    File? closingImage,
    int? serverId,
    bool isClosingOnly = false,
  }) async {
    try {
      await _databaseService.insertPendingReading({
        'pump_id': pumpId,
        'pump_name': pumpName,
        'opening_reading': openingReading,
        'closing_reading': closingReading,
        'declared_litres_sold': declaredLitresSold,
        'declared_cash_collected': declaredCashCollected,
        'attendant_id': attendantId,
        'ocr_confidence': ocrConfidence,
        'date': date.toIso8601String().split('T')[0],
        'shift': shift,
        'notes': notes,
        'opening_image_path': openingImage?.path,
        'closing_image_path': closingImage?.path,
        'created_at': DateTime.now().toIso8601String(),
        'sync_status': 'pending',
        'server_id': serverId,
        'is_closing_only': isClosingOnly ? 1 : 0,
      });

      await _updatePendingCount();

      if (_connectivityService.isConnected) syncPendingReadings();

      return true;
    } catch (e) {
      _lastError = 'Failed to queue reading: $e';
      notifyListeners();
      return false;
    }
  }

  Future<void> syncPendingReadings() async {
    if (_isSyncing) return;
    if (!_connectivityService.isConnected) return;

    _isSyncing = true;
    _lastError = null;
    notifyListeners();

    try {
      final pendingReadings = await _databaseService.getPendingReadings();

      for (final reading in pendingReadings) {
        try {
          await _databaseService.updatePendingReadingStatus(reading['id'] as int, 'syncing');

          int? serverId = reading['server_id'] as int?;
          final isClosingOnly = reading['is_closing_only'] == 1;

          if (serverId == null && !isClosingOnly) {
            final createdReading = await _apiService.createReading(
              pumpId: reading['pump_id'] as int,
              openingReading: reading['opening_reading'] as double,
              closingReading: reading['closing_reading'] as double?,
              date: DateTime.parse(reading['date'] as String),
              shift: reading['shift'] as String,
              notes: reading['notes'] as String?,
              attendantId: reading['attendant_id'] as int?,
              ocrConfidence: reading['ocr_confidence'] as double?,
            );
            serverId = createdReading.id;
            await _databaseService.updatePendingReadingServerId(reading['id'] as int, serverId);
          } else if (serverId != null && isClosingOnly) {
            final closingReading = reading['closing_reading'] as double?;
            final declaredLitres = reading['declared_litres_sold'] as double?;
            final declaredCash = reading['declared_cash_collected'] as double?;

            if (closingReading != null && declaredLitres != null && declaredCash != null) {
              await _apiService.closeReading(
                readingId: serverId,
                closingReading: closingReading,
                declaredLitresSold: declaredLitres,
                declaredCashCollected: declaredCash,
                notes: reading['notes'] as String?,
                ocrConfidence: reading['ocr_confidence'] as double?,
              );
            } else {
              // Fallback for legacy offline closings without declared fields
              await _apiService.updateReading(
                readingId: serverId,
                closingReading: closingReading,
                notes: reading['notes'] as String?,
              );
            }
          }

          if (serverId != null) {
            final openingImagePath = reading['opening_image_path'] as String?;
            if (openingImagePath != null && openingImagePath.isNotEmpty) {
              final file = File(openingImagePath);
              if (await file.exists()) {
                await _apiService.uploadImage(
                  file: file,
                  category: 'opening_reading',
                  uploadableId: serverId,
                  uploadableType: 'App\\Models\\Reading',
                );
              }
            }

            final closingImagePath = reading['closing_image_path'] as String?;
            if (closingImagePath != null && closingImagePath.isNotEmpty) {
              final file = File(closingImagePath);
              if (await file.exists()) {
                await _apiService.uploadImage(
                  file: file,
                  category: 'closing_reading',
                  uploadableId: serverId,
                  uploadableType: 'App\\Models\\Reading',
                );
              }
            }
          }

          await _databaseService.updatePendingReadingStatus(reading['id'] as int, 'synced');
        } on ApiException catch (e) {
          await _databaseService.updatePendingReadingStatus(
            reading['id'] as int,
            'failed',
            errorMessage: e.message,
          );
        } catch (e) {
          await _databaseService.updatePendingReadingStatus(
            reading['id'] as int,
            'pending',
            errorMessage: e.toString(),
          );
        }
      }

      await _databaseService.clearSyncedReadings();
    } catch (e) {
      _lastError = 'Sync failed: $e';
    } finally {
      _isSyncing = false;
      await _updatePendingCount();
      notifyListeners();
    }
  }

  Future<List<Map<String, dynamic>>> getPendingReadings() async {
    return await _databaseService.getAllPendingReadings();
  }

  Future<void> retryFailed() async {
    final db = await _databaseService.database;
    await db.update(
      'pending_readings',
      {'sync_status': 'pending', 'error_message': null},
      where: 'sync_status = ?',
      whereArgs: ['failed'],
    );
    await _updatePendingCount();
    syncPendingReadings();
  }

  Future<void> deletePending(int id) async {
    await _databaseService.deletePendingReading(id);
    await _updatePendingCount();
  }

  @override
  void dispose() {
    _connectivitySubscription?.cancel();
    super.dispose();
  }
}
