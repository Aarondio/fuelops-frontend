import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../models/reading.dart';
import '../providers/reading_provider.dart';
import '../services/format_service.dart';
import '../theme/app_theme.dart';
import '../widgets/reading_card.dart';
import 'reading_detail_screen.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  DateTime _selectedDate = DateTime.now();
  final ScrollController _dateScrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() => _searchQuery = _searchController.text.toLowerCase());
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ReadingProvider>().loadReadings(date: _selectedDate);
      _scrollToActiveDate();
    });
  }

  void _scrollToActiveDate() {
    if (_dateScrollController.hasClients) {
      _dateScrollController.animateTo(
        _dateScrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeOut,
      );
    }
  }

  Future<void> _selectDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: AppColors.primary,
              onPrimary: Colors.white,
              surface: AppColors.surface,
              onSurface: AppColors.textPrimary,
            ),
            dialogTheme: DialogThemeData(
              backgroundColor: AppColors.surface,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.lg)),
            ),
          ),
          child: child!,
        );
      },
    );

    if (date != null && date != _selectedDate && mounted) {
      setState(() {
        _selectedDate = date;
        _searchController.clear();
      });
      context.read<ReadingProvider>().loadReadings(date: date);
    }
  }

  Future<void> _handleConfirmHandover(BuildContext context, int readingId) async {
    final provider = context.read<ReadingProvider>();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Confirm Handover',
            style: TextStyle(fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
        content: const Text(
            'Confirm that this shift has been properly handed over?',
            style: TextStyle(color: AppColors.textSecondary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: AppColors.textMuted)),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      await provider.confirmHandover(readingId);
    }
  }

  @override
  void dispose() {
    _dateScrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final readingProvider = context.watch<ReadingProvider>();

    final filteredReadings = readingProvider.readings.where((reading) {
      final name = (reading.pumpName ?? 'Pump #${reading.pumpId}').toLowerCase();
      final shift = reading.shift.toLowerCase();
      return name.contains(_searchQuery) || shift.contains(_searchQuery);
    }).toList();

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
              child: Row(
                children: [
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'History',
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w900,
                            color: AppColors.textPrimary,
                            letterSpacing: -1,
                          ),
                        ),
                        Text(
                          'OPERATIONAL ARCHIVE',
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
                  _HeaderAction(icon: Icons.calendar_month_rounded, onTap: _selectDate),
                  const SizedBox(width: 10),
                  _HeaderAction(
                    icon: Icons.refresh_rounded,
                    onTap: () => readingProvider.loadReadings(date: _selectedDate),
                  ),
                ],
              ),
            ),

            // Offline / cached-data indicator
            if (!readingProvider.isOnline)
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.warning.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.cloud_off_rounded, color: AppColors.warning, size: 14),
                    SizedBox(width: 8),
                    Text(
                      'Offline — showing cached data',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppColors.warning,
                      ),
                    ),
                  ],
                ),
              ),

            // Horizontal Date Scroller
            _HorizontalDateScroller(
              scrollController: _dateScrollController,
              selectedDate: _selectedDate,
              onDateSelected: (date) {
                setState(() {
                  _selectedDate = date;
                  _searchController.clear();
                });
                readingProvider.loadReadings(date: date);
              },
            ),

            // Search Bar
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
              child: TextField(
                controller: _searchController,
                style: const TextStyle(fontSize: 14, color: AppColors.textPrimary),
                decoration: InputDecoration(
                  hintText: 'Filter logs by pump or shift...',
                  prefixIcon: const Icon(Icons.search_rounded, size: 20),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.close_rounded, size: 18),
                          onPressed: () => _searchController.clear(),
                        )
                      : null,
                ),
              ),
            ),

            // Summary Metrics
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Row(
                children: [
                  Expanded(
                    child: _CompactStat(
                      label: 'TOTAL LOGS',
                      value: FormatService.formatInteger(readingProvider.readings.length),
                      icon: Icons.analytics_rounded,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _CompactStat(
                      label: 'TOTAL VOLUME',
                      value:
                          '${FormatService.formatDecimal(readingProvider.readings.fold<double>(0, (sum, r) => sum + (r.volumeSold ?? 0)))}L',
                      icon: Icons.water_drop_rounded,
                      color: AppColors.success,
                    ),
                  ),
                ],
              ),
            ),

            // Logs List
            Expanded(
              child: RefreshIndicator(
                color: AppColors.primary,
                backgroundColor: AppColors.surface,
                onRefresh: () => readingProvider.loadReadings(date: _selectedDate),
                child: readingProvider.isLoading
                    ? const Center(
                        child: CircularProgressIndicator(color: AppColors.primary))
                    : filteredReadings.isEmpty
                        ? _buildEmptyState()
                        : ListView.builder(
                            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                            physics: const BouncingScrollPhysics(),
                            itemCount: filteredReadings.length,
                            itemBuilder: (context, index) {
                              final reading = filteredReadings[index];
                              return _TappableReadingCard(
                                reading: reading,
                                onConfirmHandover: reading.needsHandover
                                    ? () => _handleConfirmHandover(context, reading.id)
                                    : null,
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
    final isFiltering = _searchQuery.isNotEmpty;
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      child: Container(
        height: 300,
        alignment: Alignment.center,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isFiltering ? Icons.search_off_rounded : Icons.history_toggle_off_rounded,
              size: 48,
              color: AppColors.surfaceLight,
            ),
            const SizedBox(height: 16),
            Text(
              isFiltering ? 'No matching records' : 'No records found for this date',
              style: const TextStyle(
                  fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 4),
            Text(
              isFiltering ? 'Try a different keyword' : 'Try selecting a different day',
              style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
            ),
          ],
        ),
      ),
    );
  }
}

class _TappableReadingCard extends StatelessWidget {
  final Reading reading;
  final VoidCallback? onConfirmHandover;

  const _TappableReadingCard({required this.reading, this.onConfirmHandover});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => ReadingDetailScreen(reading: reading)),
      ),
      child: ReadingCard(
        pumpName: reading.pumpName ?? 'Pump #${reading.pumpId}',
        shift: reading.shift,
        openingReading: reading.openingReading,
        closingReading: reading.closingReading,
        volumeSold: reading.volumeSold,
        time: DateFormat('HH:mm').format(reading.createdAt),
        notes: reading.notes,
        varianceStatus: reading.varianceStatus,
        revenueVariance: reading.revenueVariance,
        ocrConfidence: reading.ocrConfidence,
        lowConfidenceFlag: reading.lowConfidenceFlag,
        needsHandover: reading.needsHandover,
        onConfirmHandover: onConfirmHandover,
      ),
    );
  }
}

class _HorizontalDateScroller extends StatelessWidget {
  final ScrollController scrollController;
  final DateTime selectedDate;
  final Function(DateTime) onDateSelected;

  const _HorizontalDateScroller({
    required this.scrollController,
    required this.selectedDate,
    required this.onDateSelected,
  });

  @override
  Widget build(BuildContext context) {
    final dates = List.generate(14, (index) => DateTime.now().subtract(Duration(days: index)))
        .reversed
        .toList();

    return SizedBox(
      height: 80,
      child: ListView.builder(
        controller: scrollController,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        scrollDirection: Axis.horizontal,
        itemCount: dates.length,
        itemBuilder: (context, index) {
          final date = dates[index];
          final isSelected = DateUtils.isSameDay(date, selectedDate);
          final isToday = DateUtils.isSameDay(date, DateTime.now());

          return GestureDetector(
            onTap: () => onDateSelected(date),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 56,
              margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
              decoration: BoxDecoration(
                color: isSelected ? AppColors.primary : AppColors.surface,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    DateFormat('E').format(date).toUpperCase(),
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: isSelected ? Colors.white : AppColors.textMuted,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    DateFormat('d').format(date),
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      color: isSelected ? Colors.white : AppColors.textPrimary,
                    ),
                  ),
                  if (isToday)
                    Container(
                      margin: const EdgeInsets.only(top: 4),
                      width: 4,
                      height: 4,
                      decoration: BoxDecoration(
                        color: isSelected ? Colors.white : AppColors.primary,
                        shape: BoxShape.circle,
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _CompactStat extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color? color;

  const _CompactStat({
    required this.label,
    required this.value,
    required this.icon,
    this.color,
  });

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
          Icon(icon, size: 18, color: color ?? AppColors.primary),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  color: AppColors.textPrimary,
                ),
              ),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 8,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textMuted,
                  letterSpacing: 0.5,
                ),
              ),
            ],
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
