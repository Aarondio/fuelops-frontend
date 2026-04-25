import 'package:flutter/material.dart';
import 'app_shell.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../config/app_config.dart';
import '../providers/auth_provider.dart';
import '../providers/reading_provider.dart';
import '../services/sync_service.dart';
import '../services/format_service.dart';
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
      context.read<ReadingProvider>().loadAttendants();
    });
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final reading = context.watch<ReadingProvider>();
    final sync = context.watch<SyncService>();
    final dateFormat = DateFormat('EEEE, MMMM d');

    final closedReadings = reading.readings.where((r) => r.isClosed).toList();
    final totalRevenueVariance = closedReadings.fold<double>(
        0, (sum, r) => sum + (r.revenueVariance ?? 0));
    final variantShiftsCount =
        closedReadings.where((r) => r.varianceStatus == 'red' || r.varianceStatus == 'amber').length;

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
          child: CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              // Header
              SliverPadding(
                padding: AppSpacing.pagePadding,
                sliver: SliverToBoxAdapter(
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              dateFormat.format(DateTime.now()).toUpperCase(),
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                color: AppColors.primary,
                                letterSpacing: 1.2,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              auth.user?.name ?? 'Manager',
                              style: const TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.w900,
                                color: AppColors.textPrimary,
                                letterSpacing: -1,
                              ),
                            ),
                          ],
                        ),
                      ),
                      _HeaderAction(
                        icon: Icons.notifications_none_rounded,
                        onTap: () => Navigator.of(context).pushNamed('/pending'),
                      ),
                      const SizedBox(width: 10),
                      _ProfileAvatar(name: auth.user?.name ?? 'M'),
                    ],
                  ),
                ),
              ),

              // Offline Banner
              if (!reading.isOnline)
                SliverToBoxAdapter(
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.error.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(AppRadius.md),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.cloud_off_rounded, color: AppColors.error, size: 18),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Offline Mode Active',
                            style: TextStyle(
                              color: AppColors.error,
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

              // Error Banner
              if (reading.error != null)
                SliverToBoxAdapter(
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.warning.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(AppRadius.md),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.warning_amber_rounded,
                            color: AppColors.warning, size: 18),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            reading.error!,
                            style: const TextStyle(
                              color: AppColors.warning,
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                            ),
                          ),
                        ),
                        GestureDetector(
                          onTap: () => reading.clearError(),
                          child: const Icon(Icons.close, color: AppColors.warning, size: 16),
                        ),
                      ],
                    ),
                  ),
                ),

              // Hero Volume Card
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                  child: _HeroVolumeCard(
                    volume: reading.readings
                        .fold<double>(0, (sum, r) => sum + (r.volumeSold ?? 0)),
                    shift: AppConfig.getCurrentShift().name,
                  ),
                ),
              ),

              // Variance Summary (only when there are closed shifts today)
              if (closedReadings.isNotEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                    child: _VarianceSummaryCard(
                      closedShifts: closedReadings.length,
                      totalRevenueVariance: totalRevenueVariance,
                      variantShiftsCount: variantShiftsCount,
                    ),
                  ),
                ),

              // Stats Grid
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                sliver: SliverGrid.count(
                  crossAxisCount: 2,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 1.6,
                  children: [
                    _StatWidget(
                      label: 'Active Pumps',
                      value: FormatService.formatInteger(reading.pumps.length),
                      icon: Icons.local_gas_station_rounded,
                      color: AppColors.primary,
                    ),
                    _StatWidget(
                      label: 'Pending Sync',
                      value: FormatService.formatInteger(sync.pendingCount),
                      icon: Icons.sync_rounded,
                      color: sync.pendingCount > 0 ? AppColors.warning : AppColors.success,
                      isStatus: true,
                    ),
                  ],
                ),
              ),

              // Recent Activity
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
                sliver: SliverToBoxAdapter(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Recent Activity',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          final shellState =
                              context.findAncestorStateOfType<AppShellState>();
                          shellState?.switchToTab(2);
                        },
                        child: const Text('See All', style: TextStyle(fontSize: 13)),
                      ),
                    ],
                  ),
                ),
              ),

              if (reading.readings.isEmpty)
                const SliverFillRemaining(
                  hasScrollBody: false,
                  child: _EmptyActivity(),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final r = reading.readings[index];
                        return _ActivityTile(
                          pumpName: r.pumpName ?? 'Pump #${r.pumpId}',
                          volume: r.volumeSold ?? 0,
                          shift: r.shift,
                          time: DateFormat('HH:mm').format(r.createdAt),
                          isOpen: r.isOpen,
                          varianceStatus: r.varianceStatus,
                        );
                      },
                      childCount: reading.readings.take(5).length,
                    ),
                  ),
                ),

              const SliverToBoxAdapter(child: SizedBox(height: 32)),
            ],
          ),
        ),
      ),
    );
  }
}

class _HeroVolumeCard extends StatelessWidget {
  final double volume;
  final String shift;

  const _HeroVolumeCard({required this.volume, required this.shift});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 160,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        color: AppColors.primary,
        gradient: LinearGradient(
          colors: [AppColors.primary, AppColors.primaryDark],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            shift.toUpperCase(),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.w900,
              letterSpacing: 1,
            ),
          ),
          const Spacer(),
          const Text(
            'Daily Output',
            style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 2),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                FormatService.formatDecimal(volume),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 40,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -1,
                ),
              ),
              const Padding(
                padding: EdgeInsets.only(bottom: 8, left: 6),
                child: Text(
                  'Litres',
                  style: TextStyle(
                      color: Colors.white60, fontSize: 14, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _VarianceSummaryCard extends StatelessWidget {
  final int closedShifts;
  final double totalRevenueVariance;
  final int variantShiftsCount;

  const _VarianceSummaryCard({
    required this.closedShifts,
    required this.totalRevenueVariance,
    required this.variantShiftsCount,
  });

  Color get _varianceColor {
    if (totalRevenueVariance < 0 && variantShiftsCount > 0) return AppColors.error;
    if (totalRevenueVariance < 0) return AppColors.amber;
    return AppColors.success;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: Row(
        children: [
          Expanded(
            child: _MiniStat(
              label: 'CLOSED SHIFTS',
              value: '$closedShifts',
              color: AppColors.primary,
            ),
          ),
          Container(width: 1, height: 36, color: AppColors.surfaceLight),
          Expanded(
            child: _MiniStat(
              label: 'REVENUE VARIANCE',
              value: FormatService.formatCurrency(totalRevenueVariance),
              color: _varianceColor,
            ),
          ),
          Container(width: 1, height: 36, color: AppColors.surfaceLight),
          Expanded(
            child: _MiniStat(
              label: 'FLAGGED SHIFTS',
              value: '$variantShiftsCount',
              color: variantShiftsCount > 0 ? AppColors.warning : AppColors.success,
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _MiniStat({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: color),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(
              fontSize: 8, fontWeight: FontWeight.w800, color: AppColors.textMuted, letterSpacing: 0.5),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

class _StatWidget extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final bool isStatus;

  const _StatWidget({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    this.isStatus = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Icon(icon, color: color, size: 20),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: isStatus ? color : AppColors.textPrimary,
                ),
              ),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textMuted,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ActivityTile extends StatelessWidget {
  final String pumpName;
  final double volume;
  final String shift;
  final String time;
  final bool isOpen;
  final String? varianceStatus;

  const _ActivityTile({
    required this.pumpName,
    required this.volume,
    required this.shift,
    required this.time,
    required this.isOpen,
    this.varianceStatus,
  });

  Color _statusColor() {
    if (isOpen) return AppColors.amber;
    switch (varianceStatus) {
      case 'red':
        return AppColors.error;
      case 'amber':
        return AppColors.amber;
      default:
        return AppColors.success;
    }
  }

  IconData _statusIcon() {
    if (isOpen) return Icons.timer_outlined;
    switch (varianceStatus) {
      case 'red':
        return Icons.error_outline_rounded;
      case 'amber':
        return Icons.warning_amber_rounded;
      default:
        return Icons.check_circle_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Row(
        children: [
          Icon(_statusIcon(), color: _statusColor(), size: 18),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  pumpName,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                Text(
                  isOpen
                      ? 'Awaiting closing'
                      : '${FormatService.formatDecimal(volume)} L sold',
                  style: TextStyle(
                    fontSize: 12,
                    color: isOpen ? AppColors.amber : AppColors.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          Text(
            time,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

class _HeaderAction extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _HeaderAction({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: const BoxDecoration(color: AppColors.surface, shape: BoxShape.circle),
        child: Icon(icon, color: AppColors.textPrimary, size: 20),
      ),
    );
  }
}

class _ProfileAvatar extends StatelessWidget {
  final String name;

  const _ProfileAvatar({required this.name});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 40,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(colors: [AppColors.primary, AppColors.primaryLight]),
      ),
      child: Center(
        child: Text(
          name.isNotEmpty ? name[0].toUpperCase() : '?',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w900,
            fontSize: 16,
          ),
        ),
      ),
    );
  }
}

class _EmptyActivity extends StatelessWidget {
  const _EmptyActivity();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.query_stats_rounded, size: 48, color: AppColors.surfaceLight),
          const SizedBox(height: 12),
          const Text(
            'No Recent Activity',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
