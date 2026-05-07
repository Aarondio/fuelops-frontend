import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/notification_provider.dart';
import '../providers/reading_provider.dart';
import '../models/app_notification.dart';
import '../theme/app_theme.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<NotificationProvider>().loadNotifications();
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<NotificationProvider>();
    final isOnline = context.watch<ReadingProvider>().isOnline;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'NOTIFICATIONS',
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, letterSpacing: 1),
        ),
        actions: [
          if (provider.unreadCount > 0)
            TextButton(
              onPressed: () => provider.markAllRead(),
              child: const Text(
                'Mark All Read',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
              ),
            ),
        ],
      ),
      body: _buildBody(provider, isOnline),
    );
  }

  Widget _buildBody(NotificationProvider provider, bool isOnline) {
    if (provider.isLoading) {
      return const Center(child: CircularProgressIndicator(color: AppColors.primary));
    }

    if (provider.notifications.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.notifications_none_rounded, size: 48, color: AppColors.surfaceLight),
            const SizedBox(height: 12),
            Text(
              isOnline ? 'No Notifications' : 'No Cached Notifications',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      color: AppColors.primary,
      backgroundColor: AppColors.surface,
      onRefresh: () => provider.loadNotifications(),
      child: ListView.builder(
        padding: AppSpacing.pagePadding,
        physics: const BouncingScrollPhysics(),
        itemCount: provider.notifications.length + (isOnline ? 0 : 1),
        itemBuilder: (context, index) {
          if (!isOnline && index == 0) {
            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.warning.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(AppRadius.sm),
                border: Border.all(color: AppColors.warning.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.cloud_off_rounded, color: AppColors.warning, size: 14),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Offline — showing cached notifications',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppColors.warning.withValues(alpha: 0.9),
                      ),
                    ),
                  ),
                ],
              ),
            );
          }
          final notifIndex = isOnline ? index : index - 1;
          return _NotificationTile(notification: provider.notifications[notifIndex]);
        },
      ),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  final AppNotification notification;

  const _NotificationTile({required this.notification});

  IconData get _icon {
    final type = notification.type.toLowerCase();
    if (type.contains('price')) return Icons.price_change_rounded;
    if (type.contains('variance') || type.contains('alert')) return Icons.warning_amber_rounded;
    if (type.contains('delivery')) return Icons.local_shipping_rounded;
    return Icons.notifications_rounded;
  }

  Color get _iconColor {
    final type = notification.type.toLowerCase();
    if (type.contains('variance') || type.contains('alert')) return AppColors.warning;
    if (type.contains('price')) return AppColors.amber;
    return AppColors.primary;
  }

  @override
  Widget build(BuildContext context) {
    final timeFormat = DateFormat('MMM d, HH:mm');
    final isUnread = !notification.isRead;

    return GestureDetector(
      onTap: () {
        if (isUnread) {
          context.read<NotificationProvider>().markRead(notification.id);
        }
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isUnread
              ? AppColors.primary.withValues(alpha: 0.05)
              : AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: isUnread
              ? Border.all(color: AppColors.primary.withValues(alpha: 0.2))
              : null,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: _iconColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(_icon, color: _iconColor, size: 18),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          notification.title,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: isUnread ? FontWeight.w800 : FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                      if (isUnread)
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppColors.primary,
                          ),
                        ),
                    ],
                  ),
                  if (notification.body.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      notification.body,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  const SizedBox(height: 6),
                  Text(
                    timeFormat.format(notification.createdAt),
                    style: const TextStyle(
                      fontSize: 10,
                      color: AppColors.textMuted,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
