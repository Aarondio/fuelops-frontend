import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/reading_provider.dart';
import '../services/sync_service.dart';
import '../theme/app_theme.dart';
import '../widgets/reading_card.dart';
import '../widgets/status_badge.dart';

class PendingScreen extends StatefulWidget {
  const PendingScreen({super.key});

  @override
  State<PendingScreen> createState() => _PendingScreenState();
}

class _PendingScreenState extends State<PendingScreen> {
  List<Map<String, dynamic>> _pendingReadings = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPendingReadings();
  }

  Future<void> _loadPendingReadings() async {
    setState(() => _isLoading = true);
    final readings = await context.read<ReadingProvider>().getPendingReadings();
    setState(() {
      _pendingReadings = readings;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final syncService = context.watch<SyncService>();
    final readingProvider = context.watch<ReadingProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Pending Readings'),
        actions: [
          if (syncService.isSyncing)
            const Padding(
              padding: EdgeInsets.all(16),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              ),
            )
          else if (_pendingReadings.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.sync),
              onPressed: readingProvider.isOnline
                  ? () async {
                      await readingProvider.syncNow();
                      _loadPendingReadings();
                    }
                  : null,
              tooltip: 'Sync Now',
            ),
        ],
      ),
      body: Column(
        children: [
          // Connection Status Banner
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            color: readingProvider.isOnline
                ? AppColors.successLight
                : AppColors.errorLight,
            child: Row(
              children: [
                Icon(
                  readingProvider.isOnline ? Icons.wifi : Icons.wifi_off,
                  color: readingProvider.isOnline
                      ? AppColors.success
                      : AppColors.error,
                  size: 18,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    readingProvider.isOnline
                        ? 'Online — Readings will sync automatically'
                        : 'Offline — Readings saved locally',
                    style: TextStyle(
                      fontSize: 13,
                      color: readingProvider.isOnline
                          ? AppColors.success
                          : AppColors.error,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Content
          Expanded(
            child: RefreshIndicator(
              color: AppColors.primary,
              backgroundColor: AppColors.surface,
              onRefresh: _loadPendingReadings,
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: AppColors.primary,
                      ),
                    )
                  : _pendingReadings.isEmpty
                      ? _buildEmptyState()
                      : ListView.builder(
                          padding: AppSpacing.pagePadding,
                          itemCount: _pendingReadings.length,
                          itemBuilder: (context, index) =>
                              _buildReadingCard(_pendingReadings[index]),
                        ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: AppColors.successLight,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.check_circle_outline,
                size: 40, color: AppColors.success),
          ),
          const SizedBox(height: 16),
          const Text(
            'All readings synced!',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'No pending readings to upload',
            style: TextStyle(
              fontSize: 14,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReadingCard(Map<String, dynamic> reading) {
    final status = reading['sync_status'] as String;
    final createdAt = DateTime.parse(reading['created_at'] as String);
    final dateFormat = DateFormat('MMM d, h:mm a');
    final openingReading =
        (reading['opening_reading'] as num).toDouble();
    final closingReading =
        (reading['closing_reading'] as num?)?.toDouble();
    final volume = closingReading != null
        ? closingReading - openingReading
        : null;

    Color accentColor;
    switch (status) {
      case 'failed':
        accentColor = AppColors.error;
        break;
      case 'syncing':
        accentColor = AppColors.info;
        break;
      case 'synced':
        accentColor = AppColors.success;
        break;
      default:
        accentColor = AppColors.warning;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: Column(
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: accentColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                  child: Icon(Icons.local_gas_station,
                      color: accentColor, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        reading['pump_name'] as String? ??
                            'Pump #${reading['pump_id']}',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        dateFormat.format(createdAt),
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                StatusBadge.fromSyncStatus(status),
              ],
            ),
          ),

          // Meter values — uses shared MeterValue widget
          Container(
            margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.surfaceLight,
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Row(
              children: [
                MeterValue(
                  label: 'Opening',
                  value: openingReading.toStringAsFixed(1),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8),
                  child: Icon(Icons.arrow_forward,
                      color: AppColors.textMuted, size: 16),
                ),
                MeterValue(
                  label: 'Closing',
                  value: closingReading?.toStringAsFixed(1) ?? '—',
                  valueColor: closingReading == null
                      ? AppColors.textMuted
                      : null,
                ),
                Container(
                  width: 1,
                  height: 36,
                  margin: const EdgeInsets.symmetric(horizontal: 12),
                  color: AppColors.surfaceBorder,
                ),
                MeterValue(
                  label: 'Volume',
                  value: volume != null
                      ? '${volume.toStringAsFixed(1)} L'
                      : '—',
                  valueColor: volume != null
                      ? AppColors.success
                      : AppColors.textMuted,
                ),
              ],
            ),
          ),

          // Error message
          if (reading['error_message'] != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.errorLight,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  border: Border.all(
                    color: AppColors.error.withValues(alpha: 0.2),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline,
                        size: 14, color: AppColors.error),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        reading['error_message'] as String,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.error,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // Photos indicator
          if (reading['opening_image_path'] != null ||
              reading['closing_image_path'] != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Row(
                children: const [
                  Icon(Icons.photo_outlined,
                      size: 14, color: AppColors.textMuted),
                  SizedBox(width: 6),
                  Text(
                    'Photos attached',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
