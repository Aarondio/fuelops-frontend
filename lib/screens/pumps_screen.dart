import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/reading_provider.dart';
import '../models/pump.dart';
import '../models/reading.dart';
import '../screens/capture_screen.dart';
import '../theme/app_theme.dart';

class PumpsScreen extends StatefulWidget {
  const PumpsScreen({super.key});

  @override
  State<PumpsScreen> createState() => _PumpsScreenState();
}

class _PumpsScreenState extends State<PumpsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<ReadingProvider>();
      if (provider.pumps.isEmpty) provider.loadPumps();
      provider.loadReadings(); // load today's readings to detect open ones
    });
  }

  Future<void> _refresh() async {
    final provider = context.read<ReadingProvider>();
    await Future.wait([
      provider.loadPumps(),
      provider.loadReadings(),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final reading = context.watch<ReadingProvider>();

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ────────────────────────────────
            Padding(
               padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
              child: Row(
                children: [
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Pumps',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Tap a pump to capture a reading',
                          style:
                              TextStyle(fontSize: 13, color: AppColors.textMuted),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: _refresh,
                    icon: const Icon(Icons.refresh_outlined,
                        color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // ── Pump List ─────────────────────────────
            Expanded(
              child: reading.isLoading && reading.pumps.isEmpty
                  ? const Center(
                      child: CircularProgressIndicator(
                          color: AppColors.primary),
                    )
                  : reading.pumps.isEmpty
                      ? _buildEmptyState()
                      : RefreshIndicator(
                          color: AppColors.primary,
                          backgroundColor: AppColors.surface,
                          onRefresh: _refresh,
                          child: ListView.builder(
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            itemCount: reading.pumps.length,
                            itemBuilder: (context, index) {
                              final pump = reading.pumps[index];
                              final openReading =
                                  reading.getOpenReadingForPump(pump.id);
                              final closedCount = reading.readings
                                  .where((r) =>
                                      r.pumpId == pump.id && !r.isOpen)
                                  .length;

                              return _PumpCard(
                                pump: pump,
                                openReading: openReading,
                                closedReadingsToday: closedCount,
                              );
                            },
                          ),
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: const BoxDecoration(
              color: AppColors.surfaceLight,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.local_gas_station_outlined,
                size: 40, color: AppColors.textMuted),
          ),
          const SizedBox(height: 16),
          const Text(
            'No pumps found',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Pull down to refresh',
            style: TextStyle(fontSize: 13, color: AppColors.textMuted),
          ),
        ],
      ),
    );
  }
}

// ── Pump card ───────────────────────────────────────────
class _PumpCard extends StatelessWidget {
  final Pump pump;
  final Reading? openReading;
  final int closedReadingsToday;

  const _PumpCard({
    required this.pump,
    required this.openReading,
    required this.closedReadingsToday,
  });

  Color get _productColor {
    switch (pump.productType.toUpperCase()) {
      case 'PMS':
        return AppColors.warning;
      case 'AGO':
        return AppColors.success;
      case 'DPK':
        return AppColors.info;
      default:
        return AppColors.primary;
    }
  }

  bool get _needsClosing => openReading != null;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () async {
        final result = await Navigator.of(context).pushNamed(
          '/capture',
          arguments: CaptureArgs(
            pump: pump,
            openReading: openReading,
          ),
        );
        // Refresh readings when coming back
        if (result == true && context.mounted) {
          context.read<ReadingProvider>().loadReadings();
        }
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
        child: Row(
          children: [
            // Product color indicator
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: _productColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: Icon(
                Icons.local_gas_station_rounded,
                color: _productColor,
                size: 22,
              ),
            ),
            const SizedBox(width: 14),

            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    pump.name,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      Text(
                        pump.productType,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: _productColor,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '₦${pump.currentPrice.toStringAsFixed(0)}/L',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Status badge
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (_needsClosing)
                  // Orange badge — needs closing
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.warning.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                    ),
                    child: const Text(
                      'Needs closing',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppColors.warning,
                      ),
                    ),
                  )
                else if (closedReadingsToday > 0)
                  // Green badge — done
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.success.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                    ),
                    child: Text(
                      '$closedReadingsToday done',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppColors.success,
                      ),
                    ),
                  )
                else
                  // Grey/warning badge — not read
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.warning.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                    ),
                    child: const Text(
                      'Not read',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppColors.warning,
                      ),
                    ),
                  ),
                const SizedBox(height: 6),
                const Icon(Icons.chevron_right,
                    size: 18, color: AppColors.textMuted),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
