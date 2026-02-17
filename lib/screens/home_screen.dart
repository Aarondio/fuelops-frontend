import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../config/app_config.dart';
import '../providers/auth_provider.dart';
import '../providers/reading_provider.dart';
import '../services/sync_service.dart';
import '../theme/app_theme.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ReadingProvider>().loadPumps();
      context.read<ReadingProvider>().loadReadings();
    });
  }

  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  String _shiftLabel() {
    return AppConfig.getCurrentShift().name;
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final reading = context.watch<ReadingProvider>();
    final sync = context.watch<SyncService>();
    final dateFormat = DateFormat('EEEE, MMM d');

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: RefreshIndicator(
          color: AppColors.primary,
          backgroundColor: AppColors.surface,
          onRefresh: () async {
            await reading.loadPumps();
            await reading.loadReadings();
          },
          child: reading.isLoading && reading.pumps.isEmpty
              ? const Center(
                  child: CircularProgressIndicator(
                      color: AppColors.primary))
              : ListView(
                  padding: AppSpacing.pagePadding,
                  children: [
                    // ── Greeting ────────────────────────
                    Text(
                      _greeting(),
                      style: const TextStyle(
                        fontSize: 14,
                        color: AppColors.textMuted,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      auth.user?.name ?? 'Manager',
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.calendar_today_outlined,
                            size: 13, color: AppColors.textMuted),
                        const SizedBox(width: 6),
                        Text(
                          dateFormat.format(DateTime.now()),
                          style: const TextStyle(
                              fontSize: 13, color: AppColors.textMuted),
                        ),
                        const SizedBox(width: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.12),
                            borderRadius:
                                BorderRadius.circular(AppRadius.sm),
                          ),
                          child: Text(
                            _shiftLabel(),
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 24),

                    // ── Offline Banner ──────────────────
                    if (!reading.isOnline)
                      Container(
                        margin: const EdgeInsets.only(bottom: 16),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.warningLight,
                          borderRadius:
                              BorderRadius.circular(AppRadius.md),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.wifi_off,
                                size: 16, color: AppColors.warning),
                            const SizedBox(width: 10),
                            const Expanded(
                              child: Text(
                                'You\'re offline — readings saved locally',
                                style: TextStyle(
                                    fontSize: 13,
                                    color: AppColors.warning),
                              ),
                            ),
                          ],
                        ),
                      ),

                    // ── Status Cards ────────────────────
                    Row(
                      children: [
                        Expanded(
                          child: _StatusTile(
                            icon: Icons.local_gas_station_outlined,
                            label: 'Pumps',
                            value: reading.pumps.length.toString(),
                            color: AppColors.primary,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _StatusTile(
                            icon: Icons.speed_outlined,
                            label: 'Readings Today',
                            value: reading.readings.length.toString(),
                            color: AppColors.success,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _StatusTile(
                            icon: Icons.cloud_upload_outlined,
                            label: 'Pending',
                            value: sync.pendingCount.toString(),
                            color: sync.pendingCount > 0
                                ? AppColors.warning
                                : AppColors.textMuted,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 28),

                    // ── Volume Summary ──────────────────
                    if (reading.readings.isNotEmpty) ...[
                      Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius:
                              BorderRadius.circular(AppRadius.lg),
                          border: Border(
                            left: BorderSide(
                              color: AppColors.primary,
                              width: 3,
                            ),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Today\'s Volume',
                              style: TextStyle(
                                fontSize: 13,
                                color: AppColors.textMuted,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              crossAxisAlignment:
                                  CrossAxisAlignment.end,
                              children: [
                                Text(
                                  reading.readings
                                      .fold<double>(0,
                                          (sum, r) =>
                                              sum +
                                              (r.volumeSold ?? 0))
                                      .toStringAsFixed(1),
                                  style: const TextStyle(
                                    fontSize: 32,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                const Padding(
                                  padding:
                                      EdgeInsets.only(bottom: 5),
                                  child: Text(
                                    'Litres',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: AppColors.textMuted,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 28),
                    ],

                    // ── Recent Activity ─────────────────
                    const Text(
                      'Recent Activity',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 12),

                    if (reading.readings.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(32),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius:
                              BorderRadius.circular(AppRadius.lg),
                        ),
                        child: Column(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: AppColors.surfaceLight,
                                shape: BoxShape.circle,
                              ),
                              child: Icon(Icons.speed_outlined,
                                  size: 36,
                                  color: AppColors.textMuted),
                            ),
                            const SizedBox(height: 12),
                            const Text(
                              'No readings yet today',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w500,
                                color: AppColors.textSecondary,
                              ),
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              'Go to the Pumps tab to capture your first reading',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                  fontSize: 13,
                                  color: AppColors.textMuted),
                            ),
                          ],
                        ),
                      )
                    else
                      ...reading.readings.take(5).map(
                            (r) => _ActivityItem(
                              pumpName:
                                  r.pumpName ?? 'Pump #${r.pumpId}',
                              volume: r.volumeSold ?? 0,
                              shift: r.shift,
                              time: DateFormat('h:mm a')
                                  .format(r.createdAt),
                              isOpen: r.isOpen,
                            ),
                          ),

                    const SizedBox(height: 24),
                  ],
                ),
        ),
      ),
    );
  }
}

// ── Compact status tile ─────────────────────────────────
class _StatusTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _StatusTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style:
                const TextStyle(fontSize: 11, color: AppColors.textMuted),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

// ── Recent activity timeline item ───────────────────────
class _ActivityItem extends StatelessWidget {
  final String pumpName;
  final double volume;
  final String shift;
  final String time;
  final bool isOpen;

  const _ActivityItem({
    required this.pumpName,
    required this.volume,
    required this.shift,
    required this.time,
    this.isOpen = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: isOpen
                  ? AppColors.amber.withValues(alpha: 0.12)
                  : AppColors.success.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Icon(
              isOpen
                  ? Icons.schedule_outlined
                  : Icons.check_circle_outline,
              color: isOpen ? AppColors.amber : AppColors.success,
              size: 18,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  pumpName,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  isOpen
                      ? 'Awaiting closing · ${shift.capitalize()}'
                      : '${volume.toStringAsFixed(1)} L · ${shift.capitalize()}',
                  style: const TextStyle(
                      fontSize: 12, color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
          Text(
            time,
            style: const TextStyle(
                fontSize: 12, color: AppColors.textMuted),
          ),
        ],
      ),
    );
  }
}

extension StringCap on String {
  String capitalize() =>
      isEmpty ? this : '${this[0].toUpperCase()}${substring(1)}';
}
