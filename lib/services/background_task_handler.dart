import 'dart:convert';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:workmanager/workmanager.dart';

const String emailCheckTaskName = 'com.neuralarc.voidmail.emailCheck';
const String _baseUrl = 'https://void-mail.vercel.app';

@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((taskName, inputData) async {
    if (taskName == emailCheckTaskName) {
      return await _checkForNewEmails();
    }
    return true;
  });
}

Future<bool> _checkForNewEmails() async {
  try {
    final plugin = FlutterLocalNotificationsPlugin();
    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings();
    await plugin.initialize(
      const InitializationSettings(
          android: androidSettings, iOS: iosSettings),
    );

    final prefs = await SharedPreferences.getInstance();
    final accountsJson = prefs.getString('voidmail_accounts');
    if (accountsJson == null) return true;
    final accounts =
        (jsonDecode(accountsJson) as List).cast<Map<String, dynamic>>();

    final knownIds =
        prefs.getStringList('voidmail_known_email_ids')?.toSet() ?? {};
    final newKnownIds = Set<String>.from(knownIds);

    for (final account in accounts) {
      final accessToken = account['accessToken'] as String?;
      if (accessToken == null) continue;

      var token = accessToken;
      var response = await _fetchMessages(token);

      if (response.statusCode == 401) {
        final refreshToken = account['refreshToken'] as String?;
        if (refreshToken == null) continue;
        final newToken = await _refreshToken(refreshToken);
        if (newToken == null) continue;
        token = newToken;
        account['accessToken'] = newToken;
        response = await _fetchMessages(token);
      }

      if (response.statusCode != 200) continue;

      final body = jsonDecode(response.body);
      final messages =
          body['messages'] as List? ?? body['data'] as List? ?? [];

      for (final m in messages) {
        final msg = m as Map<String, dynamic>;
        final id = msg['id'] as String? ?? '';
        if (id.isNotEmpty && !newKnownIds.contains(id)) {
          newKnownIds.add(id);

          final from = msg['from'] as Map<String, dynamic>? ?? {};
          final senderName = from['name'] as String? ??
              from['email'] as String? ??
              'Unknown';
          final subject = msg['subject'] as String? ?? '(No Subject)';

          await plugin.show(
            id.hashCode,
            senderName,
            subject,
            const NotificationDetails(
              android: AndroidNotificationDetails(
                'voidmail_emails',
                'New Emails',
                channelDescription: 'Notifications for new emails',
                importance: Importance.high,
                priority: Priority.high,
                icon: '@mipmap/ic_launcher',
              ),
              iOS: DarwinNotificationDetails(
                presentAlert: true,
                presentBadge: true,
                presentSound: true,
              ),
            ),
            payload: id,
          );
        }
      }
    }

    await prefs.setStringList(
        'voidmail_known_email_ids', newKnownIds.toList());
    await prefs.setString('voidmail_accounts', jsonEncode(accounts));

    return true;
  } catch (_) {
    return true;
  }
}

Future<http.Response> _fetchMessages(String token) {
  final uri = Uri.parse('$_baseUrl/api/gmail/messages?maxResults=20');
  return http
      .get(uri, headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      })
      .timeout(const Duration(seconds: 15));
}

Future<String?> _refreshToken(String refreshToken) async {
  try {
    final uri = Uri.parse('$_baseUrl/auth/google/refresh');
    final response = await http
        .post(
          uri,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'refresh_token': refreshToken}),
        )
        .timeout(const Duration(seconds: 15));
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final tokens = data['tokens'] as Map<String, dynamic>?;
      return tokens?['access_token'] as String?;
    }
  } catch (_) {}
  return null;
}
