import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../models/reading.dart';
import '../providers/reading_provider.dart';
import '../services/format_service.dart';
import '../theme/app_theme.dart';

class ReadingDetailScreen extends StatelessWidget {
  final Reading reading;

  const ReadingDetailScreen({super.key, required this.reading});

  Color _varianceColor() {
    switch (reading.varianceStatus) {
      case 'red':
        return AppColors.error;
      case 'amber':
        return AppColors.amber;
      case 'green':
        return AppColors.success;
      default:
        return AppColors.textMuted;
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('EEEE, MMMM d, yyyy');
    final timeFormat = DateFormat('HH:mm');

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          reading.pumpName ?? 'Pump #${reading.pumpId}',
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900, letterSpacing: 0.5),
        ),
        actions: [
          if (reading.needsHandover)
            TextButton.icon(
              onPressed: () => _confirmHandover(context),
              icon: const Icon(Icons.handshake_rounded, size: 16),
              label: const Text('Handover', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
            ),
        ],
      ),
      body: ListView(
        padding: AppSpacing.pagePadding,
        physics: const BouncingScrollPhysics(),
        children: [
          // Status header
          _buildStatusHeader(dateFormat, timeFormat),

          const SizedBox(height: 20),

          // Meter readings
          _SectionCard(
            title: 'METER READINGS',
            children: [
              _DetailRow(
                label: 'Opening',
                value: FormatService.formatDecimal(reading.openingReading),
                valueSuffix: 'L',
              ),
              if (reading.closingReading != null)
                _DetailRow(
                  label: 'Closing',
                  value: FormatService.formatDecimal(reading.closingReading!),
                  valueSuffix: 'L',
                ),
              if (reading.volumeSold != null)
                _DetailRow(
                  label: 'Volume Sold',
                  value: FormatService.formatDecimal(reading.volumeSold!),
                  valueSuffix: 'L',
                  valueColor: AppColors.success,
                ),
            ],
          ),

          if (reading.isClosed) ...[
            const SizedBox(height: 16),
            _SectionCard(
              title: 'DECLARED AMOUNTS',
              children: [
                if (reading.declaredLitresSold != null)
                  _DetailRow(
                    label: 'Declared Litres',
                    value: FormatService.formatDecimal(reading.declaredLitresSold!),
                    valueSuffix: 'L',
                  ),
                if (reading.declaredCashCollected != null)
                  _DetailRow(
                    label: 'Cash Collected',
                    value: FormatService.formatCurrency(reading.declaredCashCollected!),
                  ),
                if (reading.priceAtClose != null)
                  _DetailRow(
                    label: 'Price at Close',
                    value: FormatService.formatCurrency(reading.priceAtClose!),
                    valueSuffix: '/L',
                  ),
              ],
            ),

            const SizedBox(height: 16),
            _SectionCard(
              title: 'VARIANCE ANALYSIS',
              children: [
                if (reading.expectedRevenue != null)
                  _DetailRow(
                    label: 'Expected Revenue',
                    value: FormatService.formatCurrency(reading.expectedRevenue!),
                  ),
                if (reading.revenueVariance != null)
                  _DetailRow(
                    label: 'Revenue Variance',
                    value: FormatService.formatCurrency(reading.revenueVariance!.abs()),
                    valuePrefix: reading.revenueVariance! < 0 ? '-' : '+',
                    valueColor: _varianceColor(),
                  ),
                if (reading.volumeVariance != null)
                  _DetailRow(
                    label: 'Volume Variance',
                    value: FormatService.formatDecimal(reading.volumeVariance!.abs()),
                    valuePrefix: reading.volumeVariance! < 0 ? '-' : '+',
                    valueSuffix: 'L',
                    valueColor: _varianceColor(),
                  ),
                if (reading.varianceStatus != null)
                  _DetailRow(
                    label: 'Variance Status',
                    value: reading.varianceStatus!.toUpperCase(),
                    valueColor: _varianceColor(),
                  ),
              ],
            ),
          ],

          const SizedBox(height: 16),
          _SectionCard(
            title: 'SHIFT INFO',
            children: [
              _DetailRow(
                label: 'Shift',
                value: reading.shift.toUpperCase(),
              ),
              _DetailRow(
                label: 'Date',
                value: dateFormat.format(reading.date),
              ),
              _DetailRow(
                label: 'Recorded At',
                value: timeFormat.format(reading.createdAt),
              ),
              if (reading.closedAt != null)
                _DetailRow(
                  label: 'Closed At',
                  value: timeFormat.format(reading.closedAt!),
                ),
              if (reading.attendantId != null)
                _DetailRow(
                  label: 'Attendant ID',
                  value: '#${reading.attendantId}',
                ),
            ],
          ),

          if (reading.ocrConfidence != null) ...[
            const SizedBox(height: 16),
            _SectionCard(
              title: 'OCR SCAN',
              children: [
                _DetailRow(
                  label: 'OCR Confidence',
                  value: '${reading.ocrConfidence!.toStringAsFixed(1)}%',
                  valueColor: reading.ocrConfidence! >= 85 ? AppColors.success : AppColors.warning,
                ),
                if (reading.lowConfidenceFlag)
                  const _WarningBanner(message: 'OCR confidence below threshold — verify reading manually'),
              ],
            ),
          ],

          if (reading.handoverConfirmedAt != null) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.success.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(AppRadius.md),
                border: Border.all(color: AppColors.success.withValues(alpha: 0.2)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.handshake_rounded, size: 18, color: AppColors.success),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Handover confirmed at ${timeFormat.format(reading.handoverConfirmedAt!)}',
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.success),
                    ),
                  ),
                ],
              ),
            ),
          ],

          if (reading.needsHandover) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.amber.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(AppRadius.md),
                border: Border.all(color: AppColors.amber.withValues(alpha: 0.2)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.pending_actions_rounded, size: 18, color: AppColors.amber),
                  SizedBox(width: 12),
                  Text(
                    'Awaiting handover confirmation',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.amber),
                  ),
                ],
              ),
            ),
          ],

          if (reading.notes != null && reading.notes!.isNotEmpty) ...[
            const SizedBox(height: 16),
            _SectionCard(
              title: 'NOTES',
              children: [
                Text(
                  reading.notes!,
                  style: const TextStyle(fontSize: 14, color: AppColors.textSecondary, height: 1.5),
                ),
              ],
            ),
          ],

          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildStatusHeader(DateFormat dateFormat, DateFormat timeFormat) {
    final isOpen = reading.isOpen;
    final statusColor = isOpen
        ? AppColors.amber
        : (reading.varianceStatus == 'red'
            ? AppColors.error
            : reading.varianceStatus == 'amber'
                ? AppColors.amber
                : AppColors.success);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            statusColor.withValues(alpha: 0.15),
            statusColor.withValues(alpha: 0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: statusColor.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(100),
                ),
                child: Text(
                  isOpen ? 'OPEN' : reading.varianceStatus?.toUpperCase() ?? 'CLOSED',
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: statusColor, letterSpacing: 0.5),
                ),
              ),
              const Spacer(),
              Text(
                reading.shift.toUpperCase(),
                style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: AppColors.textMuted, letterSpacing: 1),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            reading.pumpName ?? 'Pump #${reading.pumpId}',
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: AppColors.textPrimary, letterSpacing: -0.5),
          ),
          const SizedBox(height: 4),
          Text(
            dateFormat.format(reading.date),
            style: const TextStyle(fontSize: 12, color: AppColors.textSecondary, fontWeight: FontWeight.w600),
          ),
          if (reading.volumeSold != null) ...[
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _StatChip(
                    label: 'VOLUME',
                    value: '${FormatService.formatDecimal(reading.volumeSold!)} L',
                    color: AppColors.success,
                  ),
                ),
                const SizedBox(width: 12),
                if (reading.expectedRevenue != null)
                  Expanded(
                    child: _StatChip(
                      label: 'EXPECTED',
                      value: FormatService.formatCurrency(reading.expectedRevenue!),
                      color: AppColors.primary,
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _confirmHandover(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Confirm Handover', style: TextStyle(fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
        content: const Text('Confirm this shift has been properly handed over?', style: TextStyle(color: AppColors.textSecondary)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel', style: TextStyle(color: AppColors.textMuted))),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Confirm')),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      await context.read<ReadingProvider>().confirmHandover(reading.id);
      if (context.mounted) Navigator.pop(context);
    }
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _SectionCard({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: AppColors.textMuted, letterSpacing: 1),
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;
  final String? valueSuffix;
  final String? valuePrefix;
  final Color? valueColor;

  const _DetailRow({
    required this.label,
    required this.value,
    this.valueSuffix,
    this.valuePrefix,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 13, color: AppColors.textSecondary, fontWeight: FontWeight.w600),
          ),
          Text(
            '${valuePrefix ?? ''}$value${valueSuffix ?? ''}',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: valueColor ?? AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _StatChip({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(fontSize: 8, fontWeight: FontWeight.w900, color: color, letterSpacing: 0.5)),
          const SizedBox(height: 4),
          Text(value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: color)),
        ],
      ),
    );
  }
}

class _WarningBanner extends StatelessWidget {
  final String message;
  const _WarningBanner({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          const Icon(Icons.warning_amber_rounded, size: 14, color: AppColors.warning),
          const SizedBox(width: 8),
          Expanded(
            child: Text(message, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.warning)),
          ),
        ],
      ),
    );
  }
}
