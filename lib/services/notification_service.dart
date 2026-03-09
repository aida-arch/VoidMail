import 'dart:io';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static String? pendingEmailId;
  static String? pendingEventId;

  Future<void> initialize() async {
    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    const settings = InitializationSettings(
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
    if (payload != null && payload.startsWith('event:')) {
      pendingEventId = payload.substring(6);
    } else {
      pendingEmailId = payload;
    }
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
    const androidDetails = AndroidNotificationDetails(
      'voidmail_emails',
      'New Emails',
      channelDescription: 'Notifications for new emails',
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
}
