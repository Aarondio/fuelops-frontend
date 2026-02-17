import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class StatusBadge extends StatelessWidget {
  final String label;
  final Color color;
  final IconData? icon;

  const StatusBadge({
    super.key,
    required this.label,
    required this.color,
    this.icon,
  });

  factory StatusBadge.active() => const StatusBadge(
        label: 'ACTIVE',
        color: AppColors.success,
        icon: Icons.check_circle_outline,
      );

  factory StatusBadge.inactive() => const StatusBadge(
        label: 'INACTIVE',
        color: AppColors.textMuted,
        icon: Icons.pause_circle_outline,
      );

  factory StatusBadge.pending() => const StatusBadge(
        label: 'Pending',
        color: AppColors.warning,
        icon: Icons.schedule,
      );

  factory StatusBadge.syncing() => const StatusBadge(
        label: 'Syncing...',
        color: AppColors.info,
        icon: Icons.sync,
      );

  factory StatusBadge.failed() => const StatusBadge(
        label: 'Failed',
        color: AppColors.error,
        icon: Icons.error_outline,
      );

  factory StatusBadge.synced() => const StatusBadge(
        label: 'Synced',
        color: AppColors.success,
        icon: Icons.check_circle,
      );

  factory StatusBadge.fromSyncStatus(String status) {
    switch (status) {
      case 'pending':
        return StatusBadge.pending();
      case 'syncing':
        return StatusBadge.syncing();
      case 'failed':
        return StatusBadge.failed();
      case 'synced':
        return StatusBadge.synced();
      default:
        return StatusBadge(label: status, color: AppColors.textMuted);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 13, color: color),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: color,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }
}
