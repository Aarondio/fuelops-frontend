import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/reading_provider.dart';
import '../models/pump.dart';
import '../models/reading.dart';
import '../screens/capture_screen.dart';
import '../services/format_service.dart';
import '../theme/app_theme.dart';

class PumpsScreen extends StatefulWidget {
  const PumpsScreen({super.key});

  @override
  State<PumpsScreen> createState() => _PumpsScreenState();
}

class _PumpsScreenState extends State<PumpsScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.toLowerCase();
      });
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<ReadingProvider>();
      if (provider.pumps.isEmpty) provider.loadPumps();
      provider.loadReadings();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
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
    
    final filteredPumps = reading.pumps.where((pump) {
      return pump.name.toLowerCase().contains(_searchQuery) ||
             pump.productType.toLowerCase().contains(_searchQuery);
    }).toList();

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ───────────────────────────
            Padding(
              padding: AppSpacing.pagePadding,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Pumps',
                              style: TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.w900,
                                color: AppColors.textPrimary,
                                letterSpacing: -1,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'SELECT UNIT FOR LOGGING',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                color: AppColors.primary,
                                letterSpacing: 1.2,
                              ),
                            ),
                          ],
                        ),
                      ),
                      _HeaderAction(
                        icon: Icons.refresh_rounded,
                        onTap: _refresh,
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  // ── Search Bar ─────────────────────
                  TextField(
                    controller: _searchController,
                    style: const TextStyle(fontSize: 14, color: AppColors.textPrimary),
                    decoration: InputDecoration(
                      hintText: 'Search pump name or type...',
                      prefixIcon: const Icon(Icons.search_rounded, size: 20),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.close_rounded, size: 18),
                              onPressed: () => _searchController.clear(),
                            )
                          : null,
                    ),
                  ),
                ],
              ),
            ),

            // ── Offline Banner ────────────────────────
            if (!reading.isOnline)
              Container(
                margin: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: AppColors.warning.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.cloud_off_rounded, color: AppColors.warning, size: 14),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Offline — showing cached pumps. Entries will queue for sync.',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.warning),
                      ),
                    ),
                  ],
                ),
              ),

            // ── Pump List ─────────────────────────────
            Expanded(
              child: reading.isLoading && reading.pumps.isEmpty
                  ? const Center(
                      child: CircularProgressIndicator(color: AppColors.primary),
                    )
                  : reading.pumps.isEmpty
                      ? _buildEmptyState()
                      : RefreshIndicator(
                          color: AppColors.primary,
                          backgroundColor: AppColors.surface,
                          onRefresh: _refresh,
                          child: filteredPumps.isEmpty
                              ? _buildNoResultsState()
                              : ListView.builder(
                                  padding: const EdgeInsets.symmetric(horizontal: 20),
                                  physics: const BouncingScrollPhysics(),
                                  itemCount: filteredPumps.length,
                                  itemBuilder: (context, index) {
                                    final pump = filteredPumps[index];
                                    final openReading = reading.getOpenReadingForPump(pump.id);
                                    final closedCount = reading.readings.where((r) => r.pumpId == pump.id && !r.isOpen).length;

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
          Icon(Icons.ev_station_rounded, size: 48, color: AppColors.surfaceLight),
          const SizedBox(height: 16),
          const Text(
            'No Units Detected',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoResultsState() {
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      child: Container(
        height: 300,
        alignment: Alignment.center,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.search_off_rounded, size: 48, color: AppColors.surfaceLight),
            const SizedBox(height: 16),
            const Text(
              'No pumps match your search',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 4),
            Text(
              'Try a different name or fuel type',
              style: TextStyle(fontSize: 12, color: AppColors.textMuted),
            ),
          ],
        ),
      ),
    );
  }
}

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
      case 'PMS': return AppColors.warning;
      case 'AGO': return AppColors.success;
      case 'DPK': return AppColors.info;
      default: return AppColors.primary;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () async {
              if (closedReadingsToday >= 2 && openReading == null) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Pump is fully logged for today.'),
                      backgroundColor: AppColors.warning,
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
                return;
              }
              final result = await Navigator.of(context).pushNamed(
                '/capture',
                arguments: CaptureArgs(pump: pump, openReading: openReading),
              );
              if (result == true && context.mounted) {
                context.read<ReadingProvider>().loadReadings();
              }
            },
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: _productColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(Icons.local_gas_station_rounded, color: _productColor, size: 24),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          pump.name,
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Text(
                              pump.productType,
                              style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: _productColor, letterSpacing: 0.5),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '${FormatService.formatCurrency(pump.currentPrice)}/L',
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textMuted),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        if (openReading != null)
                          const _StatusChip(label: 'OPEN', color: AppColors.warning)
                        else if (closedReadingsToday >= 2)
                          const _StatusChip(label: 'FULLY LOGGED', color: AppColors.success)
                        else if (closedReadingsToday > 0)
                          const _StatusChip(label: 'DONE', color: AppColors.success)
                        else
                          const _StatusChip(label: 'PENDING', color: AppColors.textMuted),
                        const SizedBox(height: 8),
                        const Icon(Icons.chevron_right_rounded, size: 18, color: AppColors.textMuted),
                      ],
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String label;
  final Color color;

  const _StatusChip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(100),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: color, letterSpacing: 0.5),
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
        decoration: const BoxDecoration(
          color: AppColors.surface,
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: AppColors.textPrimary, size: 20),
      ),
    );
  }
}
