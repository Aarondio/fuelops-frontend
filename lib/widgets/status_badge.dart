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
        icon: Icons.check_circle_rounded,
      );

  factory StatusBadge.inactive() => const StatusBadge(
        label: 'INACTIVE',
        color: AppColors.textMuted,
        icon: Icons.pause_circle_rounded,
      );

  factory StatusBadge.pending() => const StatusBadge(
        label: 'PENDING',
        color: AppColors.warning,
        icon: Icons.schedule_rounded,
      );

  factory StatusBadge.syncing() => const StatusBadge(
        label: 'SYNCING',
        color: AppColors.info,
        icon: Icons.sync_rounded,
      );

  factory StatusBadge.failed() => const StatusBadge(
        label: 'FAILED',
        color: AppColors.error,
        icon: Icons.error_outline_rounded,
      );

  factory StatusBadge.synced() => const StatusBadge(
        label: 'SYNCED',
        color: AppColors.success,
        icon: Icons.check_circle_rounded,
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
        return StatusBadge(label: status.toUpperCase(), color: AppColors.textMuted);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(100),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: color),
            const SizedBox(width: 6),
          ],
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: color,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}
