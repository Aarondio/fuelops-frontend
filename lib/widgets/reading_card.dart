import 'package:flutter/material.dart';
import '../services/format_service.dart';
import '../theme/app_theme.dart';

class ReadingCard extends StatelessWidget {
  final String pumpName;
  final String shift;
  final double openingReading;
  final double? closingReading;
  final double? volumeSold;
  final String? time;
  final String? notes;
  final String? varianceStatus;
  final double? revenueVariance;
  final double? ocrConfidence;
  final bool lowConfidenceFlag;
  final bool needsHandover;
  final VoidCallback? onConfirmHandover;
  final Widget? trailing;
  final Color? accentColor;

  const ReadingCard({
    super.key,
    required this.pumpName,
    required this.shift,
    required this.openingReading,
    this.closingReading,
    this.volumeSold,
    this.time,
    this.notes,
    this.varianceStatus,
    this.revenueVariance,
    this.ocrConfidence,
    this.lowConfidenceFlag = false,
    this.needsHandover = false,
    this.onConfirmHandover,
    this.trailing,
    this.accentColor,
  });

  bool get isOpen => closingReading == null;

  Color _varianceColor() {
    switch (varianceStatus) {
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
    final accent = accentColor ?? AppColors.primary;

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
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.local_gas_station_rounded, color: accent, size: 18),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        pumpName,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        shift.toUpperCase(),
                        style: const TextStyle(
                          fontSize: 9,
                          color: AppColors.textMuted,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
                if (isOpen)
                  _StatusPill(label: 'OPEN', color: AppColors.amber)
                else if (varianceStatus != null && varianceStatus != 'none')
                  _StatusPill(label: varianceStatus!.toUpperCase(), color: _varianceColor())
                else if (time != null)
                  Text(
                    time!,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textMuted,
                    ),
                  ),
                if (trailing != null) trailing!,
              ],
            ),
          ),

          // Meter values
          Container(
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 0),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.surfaceLight.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Row(
              children: [
                MeterValue(
                  label: 'OPENING',
                  value: FormatService.formatDecimal(openingReading),
                ),
                const SizedBox(width: 12),
                MeterValue(
                  label: 'CLOSING',
                  value: FormatService.formatDecimal(closingReading),
                  valueColor: isOpen ? AppColors.textMuted : null,
                ),
                const Spacer(),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Text(
                      'VOLUME',
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textMuted,
                      ),
                    ),
                    Text(
                      volumeSold != null ? '${FormatService.formatDecimal(volumeSold)} L' : '—',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: volumeSold != null ? AppColors.success : AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Variance row (closed readings with variance)
          if (!isOpen && revenueVariance != null && revenueVariance != 0)
            Container(
              margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: _varianceColor().withValues(alpha: 0.07),
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: Row(
                children: [
                  Icon(
                    revenueVariance! < 0
                        ? Icons.trending_down_rounded
                        : Icons.trending_up_rounded,
                    size: 16,
                    color: _varianceColor(),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Revenue Variance',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: _varianceColor(),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    FormatService.formatCurrency(revenueVariance!.abs()),
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                      color: _varianceColor(),
                    ),
                  ),
                ],
              ),
            ),

          // OCR low confidence indicator
          if (lowConfidenceFlag || (ocrConfidence != null && ocrConfidence! < 85))
            Container(
              margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.warning.withValues(alpha: 0.07),
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: Row(
                children: [
                  const Icon(Icons.visibility_off_rounded, size: 14, color: AppColors.warning),
                  const SizedBox(width: 8),
                  Text(
                    ocrConfidence != null
                        ? 'Low OCR confidence (${ocrConfidence!.toStringAsFixed(0)}%)'
                        : 'Low OCR confidence',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppColors.warning,
                    ),
                  ),
                ],
              ),
            ),

          // Handover confirmation button
          if (needsHandover && onConfirmHandover != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: onConfirmHandover,
                  icon: const Icon(Icons.handshake_rounded, size: 16),
                  label: const Text('CONFIRM HANDOVER',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    side: const BorderSide(color: AppColors.primary),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                ),
              ),
            ),

          // Notes
          if (notes != null && notes!.isNotEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.surfaceLight.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  notes!,
                  style: const TextStyle(
                    fontSize: 12,
                    height: 1.4,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ),

          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

class MeterValue extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;

  const MeterValue({
    super.key,
    required this.label,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 8,
            fontWeight: FontWeight.w800,
            color: AppColors.textMuted,
            letterSpacing: 0.5,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w800,
            color: valueColor ?? AppColors.textPrimary,
          ),
        ),
      ],
    );
  }
}

class _StatusPill extends StatelessWidget {
  final String label;
  final Color color;

  const _StatusPill({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(100),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: color),
      ),
    );
  }
}
