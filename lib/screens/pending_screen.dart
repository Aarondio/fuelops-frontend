import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/reading_provider.dart';
import '../services/sync_service.dart';
import '../services/format_service.dart';
import '../theme/app_theme.dart';
import '../widgets/reading_card.dart';

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
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('Sync Queue'.toUpperCase(), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900, letterSpacing: 1)),
        actions: [
          if (syncService.isSyncing)
            const Padding(
              padding: EdgeInsets.all(16),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 3, color: AppColors.primary),
              ),
            )
          else if (_pendingReadings.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.sync_rounded),
              onPressed: readingProvider.isOnline
                  ? () async {
                      await readingProvider.syncNow();
                      _loadPendingReadings();
                    }
                  : null,
            ),
        ],
      ),
      body: Column(
        children: [
          // Connection Status
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            color: readingProvider.isOnline
                ? AppColors.success.withValues(alpha: 0.1)
                : AppColors.error.withValues(alpha: 0.1),
            child: Row(
              children: [
                Icon(
                  readingProvider.isOnline ? Icons.wifi_rounded : Icons.wifi_off_rounded,
                  color: readingProvider.isOnline ? AppColors.success : AppColors.error,
                  size: 16,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    readingProvider.isOnline
                        ? 'System Link Active'
                        : 'Offline Mode Active',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: readingProvider.isOnline ? AppColors.success : AppColors.error,
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
                  ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                  : _pendingReadings.isEmpty
                      ? _buildEmptyState()
                      : ListView.builder(
                          padding: const EdgeInsets.all(20),
                          itemCount: _pendingReadings.length,
                          itemBuilder: (context, index) {
                            final reading = _pendingReadings[index];
                            final id = reading['id'] as int;
                            return Dismissible(
                              key: ValueKey(id),
                              direction: DismissDirection.endToStart,
                              background: Container(
                                alignment: Alignment.centerRight,
                                margin: const EdgeInsets.only(bottom: 12),
                                padding: const EdgeInsets.only(right: 20),
                                decoration: BoxDecoration(
                                  color: AppColors.error,
                                  borderRadius: BorderRadius.circular(AppRadius.lg),
                                ),
                                child: const Icon(Icons.delete_rounded, color: Colors.white),
                              ),
                              onDismissed: (_) async {
                                final syncService = context.read<SyncService>();
                                await syncService.deletePending(id);
                                _loadPendingReadings();
                              },
                              child: _buildPendingCard(reading),
                            );
                          },
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
          Icon(Icons.cloud_done_rounded, size: 48, color: AppColors.success),
          const SizedBox(height: 16),
          const Text(
            'Queue Cleared',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
          ),
        ],
      ),
    );
  }

  Widget _buildPendingCard(Map<String, dynamic> reading) {
    final status = reading['sync_status'] as String;
    final createdAt = DateTime.parse(reading['created_at'] as String);
    final dateFormat = DateFormat('HH:mm');
    final openingReading = (reading['opening_reading'] as num).toDouble();
    final closingReading = (reading['closing_reading'] as num?)?.toDouble();

    Color accentColor;
    String statusLabel;
    switch (status) {
      case 'failed':
        accentColor = AppColors.error;
        statusLabel = 'FAILED';
        break;
      case 'syncing':
        accentColor = AppColors.info;
        statusLabel = 'SYNCING';
        break;
      default:
        accentColor = AppColors.warning;
        statusLabel = 'PENDING';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.cloud_queue_rounded, color: accentColor, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      reading['pump_name'] as String? ?? 'Pump #${reading['pump_id']}',
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                    ),
                    Text(
                      'Logged at ${dateFormat.format(createdAt)}',
                      style: const TextStyle(fontSize: 11, color: AppColors.textMuted, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(100),
                ),
                child: Text(
                  statusLabel,
                  style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: accentColor),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.surfaceLight.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Row(
              children: [
                MeterValue(label: 'OPENING', value: FormatService.formatDecimal(openingReading)),
                const SizedBox(width: 12),
                MeterValue(
                  label: 'CLOSING',
                  value: FormatService.formatDecimal(closingReading),
                  valueColor: closingReading == null ? AppColors.textMuted : null,
                ),
              ],
            ),
          ),
          if (reading['error_message'] != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(
                reading['error_message'] as String,
                style: const TextStyle(fontSize: 11, color: AppColors.error, fontWeight: FontWeight.w600),
              ),
            ),
        ],
      ),
    );
  }
}
