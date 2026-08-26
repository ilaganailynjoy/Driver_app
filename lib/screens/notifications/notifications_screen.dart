import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/utils/format_utils.dart';
import '../../models/rider_notification.dart';
import '../../providers/notification_provider.dart';
import '../../widgets/error_widget.dart';
import '../../widgets/loading_widget.dart';

/// Rider notifications list.
class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<NotificationProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        automaticallyImplyLeading: false,
        actions: [
          if (provider.unread > 0)
            TextButton(
              onPressed: provider.markAllRead,
              child: const Text('Mark all read'),
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: provider.load,
        child: provider.loading && provider.notifications.isEmpty
            ? const LoadingWidget(label: 'Loading notifications...')
            : provider.error != null && provider.notifications.isEmpty
                ? ErrorView(
                    message: provider.error!,
                    onRetry: provider.load,
                  )
                : _buildList(provider),
      ),
    );
  }

  Widget _buildList(NotificationProvider provider) {
    if (provider.notifications.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: const [
          SizedBox(height: 100),
          Icon(Icons.notifications_none, size: 56, color: Color(0xFF9AA3AF)),
          SizedBox(height: 16),
          Text(
            'No notifications yet',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
        ],
      );
    }

    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      itemCount: provider.notifications.length,
      itemBuilder: (context, index) {
        final n = provider.notifications[index];
        return _NotificationTile(
          notification: n,
          onTap: () => provider.markRead(n.id),
        );
      },
    );
  }
}

class _NotificationTile extends StatelessWidget {
  const _NotificationTile({required this.notification, this.onTap});

  final RiderNotification notification;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final isRead = notification.isRead;
    final title = notification.title;
    final body = notification.body;
    final createdAt = notification.createdAt;
    final icon = switch (notification.type) {
      'delivery' => Icons.local_shipping_outlined,
      'earnings' => Icons.savings_outlined,
      'announcement' => Icons.campaign_outlined,
      _ => Icons.notifications_outlined,
    };

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: isRead
                      ? const Color(0xFFE6E9EF)
                      : const Color(0xFF1E6F5C).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  icon,
                  size: 20,
                  color: isRead
                      ? const Color(0xFF9AA3AF)
                      : const Color(0xFF1E6F5C),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontWeight:
                            isRead ? FontWeight.w500 : FontWeight.w800,
                        fontSize: 14,
                      ),
                    ),
                    if (body != null && body.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        body,
                        style: const TextStyle(
                          fontSize: 13,
                          color: Color(0xFF4B5563),
                          height: 1.35,
                        ),
                      ),
                    ],
                    const SizedBox(height: 6),
                    Text(
                      FormatUtils.timeAgo(createdAt),
                      style: const TextStyle(
                          fontSize: 11, color: Color(0xFF9AA3AF)),
                    ),
                  ],
                ),
              ),
              if (!isRead)
                Container(
                  width: 8,
                  height: 8,
                  margin: const EdgeInsets.only(top: 6),
                  decoration: const BoxDecoration(
                    color: Color(0xFF1E6F5C),
                    shape: BoxShape.circle,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}