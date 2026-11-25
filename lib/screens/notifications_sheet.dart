import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models.dart';
import '../providers/app_providers.dart';
import '../utils/app_typography.dart';
import '../widgets/animated_ui.dart';

class NotificationsSheet extends StatelessWidget {
  const NotificationsSheet({super.key});

  @override
  Widget build(BuildContext context) {
    final offerProvider = context.watch<OfferProvider>();
    final notifications = offerProvider.notifications;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      maxChildSize: 0.92,
      minChildSize: 0.45,
      builder: (_, scrollController) => Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF181B22) : const Color(0xFFF7F8FC),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 12),
            Container(
              width: 44,
              height: 5,
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF2E3442) : Colors.grey.shade300,
                borderRadius: BorderRadius.circular(99),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(9),
                    decoration: BoxDecoration(
                      color: const Color(0xFFC69C55).withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.notifications_active_rounded,
                      color: Color(0xFFC69C55),
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Campus Activity & Offers',
                          style: AppTypography.display(size: 20),
                        ),
                        Text(
                          '${offerProvider.unreadNotificationCount} unread updates',
                          style: TextStyle(
                            color: isDark ? Colors.grey.shade400 : const Color(0xFF7A8191),
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (notifications.isNotEmpty)
                    TextButton.icon(
                      onPressed: () => offerProvider.markAllNotificationsRead(),
                      icon: const Icon(Icons.done_all_rounded, size: 18),
                      label: const Text('Mark all read'),
                    ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: notifications.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 76,
                              height: 76,
                              decoration: BoxDecoration(
                                color: const Color(0xFF667B72).withValues(alpha: 0.12),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.notifications_none_rounded,
                                size: 38,
                                color: Color(0xFF667B72),
                              ),
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              'All caught up!',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'You will receive instant alerts here whenever a campus peer makes an offer, counters, or accepts your listing.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: isDark ? Colors.grey.shade400 : const Color(0xFF777D8E),
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  : ListView.separated(
                      controller: scrollController,
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 30),
                      itemCount: notifications.length,
                      separatorBuilder: (context, index) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final item = notifications[index];
                        return StaggeredSlideFade(
                          index: index,
                          child: _NotificationCard(
                            item: item,
                            onTap: () {
                              offerProvider.markNotificationRead(item.id);
                              Navigator.pop(context);
                            },
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NotificationCard extends StatelessWidget {
  final AppNotification item;
  final VoidCallback onTap;

  const _NotificationCard({
    required this.item,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    IconData icon;
    Color iconColor;
    Color iconBg;

    switch (item.type) {
      case 'offer_accepted':
        icon = Icons.check_circle_outline_rounded;
        iconColor = const Color(0xFF24A889);
        iconBg = const Color(0xFF24A889).withValues(alpha: 0.12);
        break;
      case 'counter_offer':
        icon = Icons.swap_horiz_rounded;
        iconColor = const Color(0xFFF2A14A);
        iconBg = const Color(0xFFF2A14A).withValues(alpha: 0.12);
        break;
      case 'offer_declined':
        icon = Icons.cancel_outlined;
        iconColor = const Color(0xFFD94B64);
        iconBg = const Color(0xFFD94B64).withValues(alpha: 0.12);
        break;
      default:
        icon = Icons.local_offer_outlined;
        iconColor = const Color(0xFF252832);
        iconBg = const Color(0xFF252832).withValues(alpha: 0.10);
        break;
    }

    return BouncyTap(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isDark
              ? (item.isRead ? const Color(0xFF1E222B) : const Color(0xFF252A36))
              : (item.isRead ? Colors.white : const Color(0xFFF2F4FA)),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDark
                ? (item.isRead ? const Color(0xFF2E3442) : const Color(0xFF667B72).withValues(alpha: 0.4))
                : (item.isRead ? Colors.grey.shade200 : const Color(0xFF667B72).withValues(alpha: 0.25)),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: iconBg,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: iconColor, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          item.title,
                          style: TextStyle(
                            fontWeight: item.isRead ? FontWeight.w700 : FontWeight.w900,
                            fontSize: 14,
                          ),
                        ),
                      ),
                      Text(
                        _formatTime(item.timestamp),
                        style: TextStyle(
                          color: isDark ? Colors.grey.shade500 : const Color(0xFF9196A4),
                          fontSize: 11,
                        ),
                      ),
                      if (!item.isRead) ...[
                        const SizedBox(width: 6),
                        const PulsingStatusDot(
                          color: Color(0xFFD94B64),
                          size: 7,
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    item.body,
                    style: TextStyle(
                      color: isDark ? Colors.grey.shade300 : const Color(0xFF4A4E5D),
                      fontSize: 13,
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

  String _formatTime(DateTime time) {
    final diff = DateTime.now().difference(time);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}
