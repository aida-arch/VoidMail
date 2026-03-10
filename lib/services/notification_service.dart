import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;

/// Notification action identifiers
class NotificationActions {
  static const String reply = 'REPLY_ACTION';
  static const String archive = 'ARCHIVE_ACTION';
  static const String markRead = 'MARK_READ_ACTION';
  static const String categoryId = 'NEW_EMAIL';
}

/// Callback for notification actions (set by the app)
typedef NotificationActionCallback = void Function(String action, String? emailId);

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static String? pendingEmailId;
  static String? pendingEventId;

  /// Callback for notification action handling
  static NotificationActionCallback? onNotificationAction;

  /// Badge count tracking
  int _badgeCount = 0;
  int get badgeCount => _badgeCount;

  Future<void> initialize() async {
    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    // iOS: define notification categories with actions
    final iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
      notificationCategories: [
        DarwinNotificationCategory(
          NotificationActions.categoryId,
          actions: <DarwinNotificationAction>[
            DarwinNotificationAction.plain(
              NotificationActions.reply,
              'Reply',
              options: <DarwinNotificationActionOption>{
                DarwinNotificationActionOption.foreground,
              },
            ),
            DarwinNotificationAction.plain(
              NotificationActions.archive,
              'Archive',
              options: <DarwinNotificationActionOption>{
                DarwinNotificationActionOption.destructive,
              },
            ),
            DarwinNotificationAction.plain(
              NotificationActions.markRead,
              'Mark Read',
            ),
          ],
        ),
      ],
    );

    final settings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _plugin.initialize(
      settings,
      onDidReceiveNotificationResponse: _onNotificationTap,
    );
  }

  void _onNotificationTap(NotificationResponse response) {
    final payload = response.payload;
    final actionId = response.actionId;

    if (payload != null && payload.startsWith('event:')) {
      pendingEventId = payload.substring(6);
      return;
    }

    // Handle notification actions
    if (actionId != null && actionId.isNotEmpty && payload != null) {
      debugPrint('[Notification] Action: $actionId for email: $payload');
      onNotificationAction?.call(actionId, payload);
      return;
    }

    // Default tap — navigate to email
    pendingEmailId = payload;
  }

  Future<void> requestPermissions() async {
    if (Platform.isIOS) {
      await _plugin
          .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin>()
          ?.requestPermissions(alert: true, badge: true, sound: true);
    } else if (Platform.isAndroid) {
      await _plugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.requestNotificationsPermission();
    }
  }

  Future<void> showEmailNotification({
    required String emailId,
    required String senderName,
    required String subject,
  }) async {
    // Android: action buttons via notification actions
    const androidDetails = AndroidNotificationDetails(
      'voidmail_emails',
      'New Emails',
      channelDescription: 'Notifications for new emails',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
      actions: <AndroidNotificationAction>[
        AndroidNotificationAction(
          NotificationActions.reply,
          'Reply',
          showsUserInterface: true,
        ),
        AndroidNotificationAction(
          NotificationActions.archive,
          'Archive',
        ),
        AndroidNotificationAction(
          NotificationActions.markRead,
          'Mark Read',
        ),
      ],
    );

    // iOS: use notification category for actions
    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      categoryIdentifier: NotificationActions.categoryId,
    );

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    // Increment badge count
    _badgeCount++;

    await _plugin.show(
      emailId.hashCode,
      senderName,
      subject,
      details,
      payload: emailId,
    );
  }

  /// Schedule a future event reminder notification
  Future<void> scheduleEventReminder({
    required String eventId,
    required String title,
    required String timeRange,
    required DateTime eventStart,
    required int minutesBefore,
  }) async {
    final scheduledDate =
        eventStart.subtract(Duration(minutes: minutesBefore));

    // Don't schedule if the reminder time has already passed
    if (scheduledDate.isBefore(DateTime.now())) return;

    const androidDetails = AndroidNotificationDetails(
      'voidmail_events',
      'Event Reminders',
      channelDescription: 'Reminders for upcoming calendar events',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
    );
    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );
    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    final tzScheduled = tz.TZDateTime.from(scheduledDate, tz.local);
    await _plugin.zonedSchedule(
      eventId.hashCode,
      title,
      'Starting in $minutesBefore minutes',
      tzScheduled,
      details,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      payload: 'event:$eventId',
    );
  }

  /// Cancel a scheduled event reminder
  Future<void> cancelEventReminder(String eventId) async {
    await _plugin.cancel(eventId.hashCode);
  }

  /// Clear badge count and remove delivered notifications
  Future<void> clearBadge() async {
    _badgeCount = 0;
    // Remove all delivered notifications
    await _plugin.cancelAll();
  }

  /// Reset badge count without canceling notifications
  void resetBadgeCount() {
    _badgeCount = 0;
  }
}
