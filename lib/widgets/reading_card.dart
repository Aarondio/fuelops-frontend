import 'package:flutter/material.dart';
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
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                  child: Icon(
                    Icons.local_gas_station,
                    color: accent,
                    size: 20,
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
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        shift.toUpperCase(),
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.textMuted,
                          fontWeight: FontWeight.w500,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
                if (isOpen)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.amber.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                    ),
                    child: const Text(
                      'Open',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.amber,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                if (!isOpen && time != null)
                  Text(
                    time!,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textMuted,
                    ),
                  ),
                if (trailing != null) trailing!,
              ],
            ),
          ),

          // Meter values
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
                    value: openingReading.toStringAsFixed(1)),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8),
                  child: Icon(Icons.arrow_forward,
                      color: AppColors.textMuted, size: 16),
                ),
                MeterValue(
                  label: 'Closing',
                  value: closingReading?.toStringAsFixed(1) ?? '—',
                  valueColor: isOpen ? AppColors.textMuted : null,
                ),
                Container(
                  width: 1,
                  height: 36,
                  margin: const EdgeInsets.symmetric(horizontal: 12),
                  color: AppColors.surfaceBorder,
                ),
                MeterValue(
                  label: 'Volume',
                  value: volumeSold != null
                      ? '${volumeSold!.toStringAsFixed(1)} L'
                      : '—',
                  valueColor: volumeSold != null
                      ? AppColors.success
                      : AppColors.textMuted,
                ),
              ],
            ),
          ),

          // Notes
          if (notes != null && notes!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.note_outlined,
                      size: 14, color: AppColors.textMuted),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      notes!,
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                      ),
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

/// Shared meter value widget used in [ReadingCard] and pending screen.
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
    return Expanded(
      child: Column(
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              color: AppColors.textMuted,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: valueColor ?? AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}
