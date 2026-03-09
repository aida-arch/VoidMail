import 'dart:async';
import 'package:flutter/material.dart';

/// Notification data model
class NotificationData {
  final String id;
  final String senderName;
  final String subject;
  final String snippet;
  final String emailId;
  final DateTime timestamp;

  NotificationData({
    String? id,
    required this.senderName,
    required this.subject,
    required this.snippet,
    required this.emailId,
    DateTime? timestamp,
  })  : id = id ?? DateTime.now().millisecondsSinceEpoch.toString(),
        timestamp = timestamp ?? DateTime.now();
}

/// In-App Notification Manager
/// Shows banner notifications within the app for new emails.
/// Auto-dismisses after 4 seconds. Supports queuing.
class InAppNotificationManager extends ChangeNotifier {
  static final InAppNotificationManager _instance =
      InAppNotificationManager._internal();
  factory InAppNotificationManager() => _instance;
  InAppNotificationManager._internal();

  NotificationData? _currentNotification;
  bool _isShowing = false;
  Timer? _dismissTimer;
  final List<NotificationData> _queue = [];

  NotificationData? get currentNotification => _currentNotification;
  bool get isShowing => _isShowing;

  /// Show a notification banner
  void show({
    required String senderName,
    required String subject,
    required String snippet,
    required String emailId,
  }) {
    final data = NotificationData(
      senderName: senderName,
      subject: subject,
      snippet: snippet,
      emailId: emailId,
    );

    if (_isShowing) {
      // Queue the notification
      _queue.add(data);
      return;
    }

    _showNotification(data);
  }

  void _showNotification(NotificationData data) {
    // Cancel any pending auto-dismiss
    _dismissTimer?.cancel();

    _currentNotification = data;
    _isShowing = true;
    notifyListeners();

    // Auto-dismiss after 4 seconds
    _dismissTimer = Timer(const Duration(seconds: 4), () {
      dismiss();
    });
  }

  /// Dismiss the current notification
  void dismiss() {
    _dismissTimer?.cancel();
    _dismissTimer = null;

    _isShowing = false;
    notifyListeners();

    // Clear data after animation completes, then show next if queued
    Future.delayed(const Duration(milliseconds: 350), () {
      if (!_isShowing) {
        _currentNotification = null;
        notifyListeners();

        // Show next queued notification
        if (_queue.isNotEmpty) {
          final next = _queue.removeAt(0);
          Future.delayed(const Duration(milliseconds: 200), () {
            _showNotification(next);
          });
        }
      }
    });
  }

  @override
  void dispose() {
    _dismissTimer?.cancel();
    super.dispose();
  }
}
