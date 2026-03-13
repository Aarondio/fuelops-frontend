import 'package:flutter/material.dart';
import '../services/format_service.dart';
import '../theme/app_theme.dart';

class ReadingCard extends StatelessWidget {
  final String pumpName;
  final String shift;
  final double openingReading;
  final double? closingReading;
  final String? time;
  final String? notes;
  final Widget? trailing;
  final Color? accentColor;

  const ReadingCard({
    super.key,
    required this.pumpName,
    required this.shift,
    required this.openingReading,
    this.closingReading,
    this.time,
    this.notes,
    this.trailing,
    this.accentColor,
  });

  bool get isOpen => closingReading == null;
  double? get volumeSold =>
      closingReading != null ? closingReading! - openingReading : null;

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
                  child: Icon(
                    Icons.local_gas_station_rounded,
                    color: accent,
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
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.surfaceLight.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Row(
              children: [
                MeterValue(
                    label: 'OPENING',
                    value: FormatService.formatDecimal(openingReading)),
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
                      volumeSold != null
                          ? '${FormatService.formatDecimal(volumeSold)} L'
                          : '—',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: volumeSold != null
                            ? AppColors.success
                            : AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Notes
          if (notes != null && notes!.isNotEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
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
