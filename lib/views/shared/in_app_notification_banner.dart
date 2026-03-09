import 'package:flutter/material.dart';
import '../../design_system/colors.dart';
import '../../design_system/typography.dart';
import '../../services/in_app_notification_manager.dart';

/// In-App Notification Banner
/// Slides down from the top when a new email arrives.
/// Mirrors InAppNotificationBanner.swift from the reference iOS app.
class InAppNotificationBanner extends StatelessWidget {
  final InAppNotificationManager manager;
  final void Function(String emailId)? onTap;

  const InAppNotificationBanner({
    super.key,
    required this.manager,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: manager,
      builder: (context, child) {
        return AnimatedPositioned(
          duration: const Duration(milliseconds: 450),
          curve: Curves.easeOutBack,
          top: manager.isShowing ? 8 : -120,
          left: 16,
          right: 16,
          child: manager.currentNotification != null
              ? _buildBanner(context, manager.currentNotification!)
              : const SizedBox(),
        );
      },
    );
  }

  Widget _buildBanner(BuildContext context, NotificationData notification) {
    return GestureDetector(
      onTap: () {
        onTap?.call(notification.emailId);
        manager.dismiss();
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: VoidColors.bgCard,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Mail icon
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: VoidColors.bgDeep,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.email,
                size: 18,
                color: VoidColors.accentSkyBlue,
              ),
            ),
            const SizedBox(width: 12),

            // Text content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Sender + timestamp
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          notification.senderName,
                          style: Typo.headline.copyWith(fontSize: 14),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        'now',
                        style: Typo.monoSmall,
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),

                  // Subject
                  Text(
                    notification.subject,
                    style: Typo.subhead.copyWith(
                      fontSize: 13,
                      color: VoidColors.textSecondary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),

                  // Snippet
                  Text(
                    notification.snippet,
                    style: Typo.subhead.copyWith(
                      fontSize: 13,
                      color: VoidColors.textTertiary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),

            // Close button
            GestureDetector(
              onTap: () => manager.dismiss(),
              child: Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: VoidColors.bgDeep,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Icon(
                  Icons.close,
                  size: 12,
                  color: VoidColors.textTertiary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Helper widget that wraps AnimatedBuilder for ChangeNotifier
class AnimatedBuilder extends StatelessWidget {
  final Listenable animation;
  final Widget Function(BuildContext context, Widget? child) builder;
  final Widget? child;

  const AnimatedBuilder({
    super.key,
    required this.animation,
    required this.builder,
    this.child,
  });

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: animation,
      builder: builder,
      child: child,
    );
  }
}
