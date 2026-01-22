import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/notification_model.dart';
import '../providers/notification_provider.dart';
import 'chat_detail_screen.dart';

/// 알림 화면
/// 도착한 알림들을 리스트로 표시하고, 읽음/삭제 처리를 제공합니다.
class NotificationScreen extends StatefulWidget {
  const NotificationScreen({super.key});

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
  // 색상 상수
  static const Color primaryBlue = Color(0xFF3E97EA);
  static const Color textDark = Color(0xFF111518);
  static const Color textMuted = Color(0xFF637688);
  static const Color backgroundLight = Color(0xFFF6F7F8);
  static const Color surfaceWhite = Color(0xFFFFFFFF);

  @override
  void initState() {
    super.initState();
    // 화면 진입 시 알림 구독 시작
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<NotificationProvider>().startListeningNotifications();
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<NotificationProvider>();
    final notifications = provider.notifications;
    final isLoading = provider.isLoadingNotifications;

    return Scaffold(
      backgroundColor: backgroundLight,
      appBar: AppBar(
        backgroundColor: surfaceWhite,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.chevron_left, color: textDark, size: 28),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          '알림',
          style: TextStyle(
            color: textDark,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        actions: [
          if (notifications.isNotEmpty)
            TextButton(
              onPressed: () => provider.markAllAsRead(),
              child: const Text('모두 읽음',
                  style: TextStyle(
                      color: primaryBlue,
                      fontSize: 14,
                      fontWeight: FontWeight.w600)),
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline, color: textMuted),
              tooltip: '전체 삭제',
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    scrollable: true,
                    title: const Text('알림 전체 삭제'),
                    content: const Text('모든 알림을 삭제하시겠습니까?'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('취소',
                            style: TextStyle(color: Colors.grey)),
                      ),
                      TextButton(
                        onPressed: () {
                          provider.deleteAllNotifications();
                          Navigator.pop(context);
                        },
                        child: const Text('삭제',
                            style: TextStyle(color: Colors.red)),
                      ),
                    ],
                  ),
                );
              },
            ),
            const SizedBox(width: 8),
          ],
      ),
      body: _buildBody(isLoading, notifications, provider),
    );
  }

  Widget _buildBody(
    bool isLoading,
    List<NotificationModel> notifications,
    NotificationProvider provider,
  ) {
    if (isLoading) {
      return const Center(
        child: CircularProgressIndicator(strokeWidth: 2, color: primaryBlue),
      );
    }

    if (notifications.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.notifications_off_outlined,
              size: 72,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            const Text(
              '알림이 없어요',
              style: TextStyle(
                color: textMuted,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              '새로운 소식이 있으면 여기에 표시됩니다',
              style: TextStyle(
                color: textMuted,
                fontSize: 14,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: notifications.length,
      separatorBuilder: (_, __) => const Divider(height: 1, indent: 72),
      itemBuilder: (context, index) {
        final notification = notifications[index];
        return _NotificationTile(
          notification: notification,
          onTap: () => _handleTap(notification, provider),
          onDismissed: () => provider.deleteNotification(notification.id),
        );
      },
    );
  }

  void _handleTap(NotificationModel notification, NotificationProvider provider) {
    // 읽음 처리
    if (!notification.isRead) {
      provider.markAsRead(notification.id);
    }

    // 타입에 따라 네비게이션
    switch (notification.type) {
      case NotificationType.chat:
        final chatId = notification.data['chatId'] ?? notification.data['roomId'];
        if (chatId != null) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ChatDetailScreen(chatId: chatId.toString()),
            ),
          );
        }
        break;
      case NotificationType.like:
      case NotificationType.system:
      case NotificationType.marketing:
        // 추후 상세 화면 연결
        break;
    }
  }
}

/// 알림 타일 위젯
class _NotificationTile extends StatelessWidget {
  final NotificationModel notification;
  final VoidCallback onTap;
  final VoidCallback onDismissed;

  const _NotificationTile({
    required this.notification,
    required this.onTap,
    required this.onDismissed,
  });

  static const Color primaryBlue = Color(0xFF3E97EA);
  static const Color textDark = Color(0xFF111518);
  static const Color textMuted = Color(0xFF637688);
  static const Color unreadBg = Color(0xFFE3F2FD);

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: Key(notification.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        color: Colors.red,
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      onDismissed: (_) => onDismissed(),
      child: Material(
        color: notification.isRead ? Colors.white : unreadBg,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 알림 아이콘
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: _getIconBackgroundColor(),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    _getIcon(),
                    color: _getIconColor(),
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                // 알림 내용
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
                                fontSize: 15,
                                fontWeight: notification.isRead 
                                    ? FontWeight.w500 
                                    : FontWeight.bold,
                                color: textDark,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _formatTime(notification.createdAt),
                            style: const TextStyle(
                              fontSize: 12,
                              color: textMuted,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        notification.body,
                        style: const TextStyle(
                          fontSize: 14,
                          color: textMuted,
                          height: 1.4,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                // 읽지 않음 표시
                if (!notification.isRead)
                  Container(
                    width: 8,
                    height: 8,
                    margin: const EdgeInsets.only(left: 8, top: 6),
                    decoration: const BoxDecoration(
                      color: primaryBlue,
                      shape: BoxShape.circle,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  IconData _getIcon() {
    switch (notification.type) {
      case NotificationType.chat:
        return Icons.chat_bubble_rounded;
      case NotificationType.like:
        return Icons.favorite_rounded;
      case NotificationType.marketing:
        return Icons.campaign_rounded;
      case NotificationType.system:
        return Icons.info_rounded;
    }
  }

  Color _getIconColor() {
    switch (notification.type) {
      case NotificationType.chat:
        return const Color(0xFF0077A7);
      case NotificationType.like:
        return Colors.redAccent;
      case NotificationType.marketing:
        return Colors.orange;
      case NotificationType.system:
        return primaryBlue;
    }
  }

  Color _getIconBackgroundColor() {
    switch (notification.type) {
      case NotificationType.chat:
        return const Color(0xFFE6F6FF);
      case NotificationType.like:
        return Colors.red.shade50;
      case NotificationType.marketing:
        return Colors.orange.shade50;
      case NotificationType.system:
        return const Color(0xFFE3F2FD);
    }
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final diff = now.difference(time);

    if (diff.inMinutes < 1) return '방금';
    if (diff.inMinutes < 60) return '${diff.inMinutes}분 전';
    if (diff.inHours < 24) return '${diff.inHours}시간 전';
    if (diff.inDays < 7) return '${diff.inDays}일 전';
    return '${time.month}/${time.day}';
  }
}
