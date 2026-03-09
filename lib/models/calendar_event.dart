import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../design_system/colors.dart';

/// Calendar Event
class CalendarEvent {
  final String id;
  final String title;
  final DateTime startDate;
  final DateTime endDate;
  final String? location;
  final String? meetingLink;
  final Color color;
  final String calendarName;
  final String? linkedEmailId;
  final String? accountEmail;
  final String? organizerEmail;
  final List<String> attendees;
  final String? description;
  final int? reminderMinutes;

  CalendarEvent({
    required this.id,
    required this.title,
    required this.startDate,
    required this.endDate,
    this.location,
    this.meetingLink,
    this.color = VoidColors.accentSkyBlue,
    this.calendarName = 'Calendar',
    this.linkedEmailId,
    this.accountEmail,
    this.organizerEmail,
    this.attendees = const [],
    this.description,
    this.reminderMinutes,
  });

  String? get colorId {
    if (color == VoidColors.accentSkyBlue) return '1';
    if (color == VoidColors.accentGreen) return '2';
    if (color == const Color(0xFF9966CC)) return '3';
    if (color == VoidColors.accentPink) return '4';
    if (color == VoidColors.accentYellow) return '5';
    return null;
  }

  CalendarEvent copyWith({
    String? title,
    DateTime? startDate,
    DateTime? endDate,
    String? location,
    String? meetingLink,
    Color? color,
    String? description,
    List<String>? attendees,
    int? reminderMinutes,
  }) {
    return CalendarEvent(
      id: id,
      title: title ?? this.title,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      location: location ?? this.location,
      meetingLink: meetingLink ?? this.meetingLink,
      color: color ?? this.color,
      calendarName: calendarName,
      linkedEmailId: linkedEmailId,
      accountEmail: accountEmail,
      organizerEmail: organizerEmail,
      attendees: attendees ?? this.attendees,
      description: description ?? this.description,
      reminderMinutes: reminderMinutes ?? this.reminderMinutes,
    );
  }

  String get duration {
    final diff = endDate.difference(startDate);
    if (diff.inHours > 0) {
      final mins = diff.inMinutes % 60;
      return mins > 0 ? '${diff.inHours}h ${mins}m' : '${diff.inHours}h';
    }
    return '${diff.inMinutes}m';
  }

  String get timeRange {
    final startFmt = DateFormat('h:mm a').format(startDate);
    final endFmt = DateFormat('h:mm a').format(endDate);
    return '$startFmt – $endFmt';
  }

  String get startTimeFormatted => DateFormat('h:mm a').format(startDate);

  String? get meetingPlatform {
    if (meetingLink == null) return null;
    if (meetingLink!.contains('meet.google.com')) return 'Google Meet';
    if (meetingLink!.contains('zoom.us')) return 'Zoom';
    if (meetingLink!.contains('teams.microsoft.com')) return 'Teams';
    return 'Video Call';
  }

  factory CalendarEvent.fromJson(Map<String, dynamic> json) {
    Color eventColor = VoidColors.accentSkyBlue;
    if (json['colorId'] != null) {
      final colors = {
        '1': VoidColors.accentSkyBlue,
        '2': VoidColors.accentGreen,
        '3': const Color(0xFF9966CC),
        '4': VoidColors.accentPink,
        '5': VoidColors.accentYellow,
      };
      eventColor = colors[json['colorId']] ?? VoidColors.accentSkyBlue;
    }

    String? meetLink;
    if (json['conferenceData'] != null) {
      final entries = json['conferenceData']['entryPoints'] as List?;
      if (entries != null && entries.isNotEmpty) {
        meetLink = entries.first['uri'];
      }
    }
    meetLink ??= json['hangoutLink'];

    return CalendarEvent(
      id: json['id'] ?? '',
      title: json['summary'] ?? 'Untitled Event',
      startDate: _parseDate(json['start']),
      endDate: _parseDate(json['end']),
      location: json['location'],
      meetingLink: meetLink,
      color: eventColor,
      calendarName: json['calendarName'] ?? 'Calendar',
      accountEmail: json['accountEmail'],
      organizerEmail: json['organizer']?['email'],
      attendees: (json['attendees'] as List?)
              ?.map((a) => a['email'] as String)
              .toList() ??
          [],
      description: json['description'],
      reminderMinutes: _parseReminder(json),
    );
  }

  static int? _parseReminder(Map<String, dynamic> json) {
    final reminders = json['reminders'];
    if (reminders == null) return null;
    final overrides = reminders['overrides'] as List?;
    if (overrides != null && overrides.isNotEmpty) {
      return overrides.first['minutes'] as int?;
    }
    return null;
  }

  static DateTime _parseDate(dynamic dateObj) {
    if (dateObj == null) return DateTime.now();
    if (dateObj is String) return DateTime.tryParse(dateObj) ?? DateTime.now();
    if (dateObj is Map) {
      final dt = dateObj['dateTime'] ?? dateObj['date'];
      if (dt != null) return DateTime.tryParse(dt) ?? DateTime.now();
    }
    return DateTime.now();
  }
}

/// Calendar Day - for grid
class CalendarDay {
  final DateTime date;
  final List<CalendarEvent> events;
  final bool isCurrentMonth;

  CalendarDay({
    required this.date,
    this.events = const [],
    this.isCurrentMonth = true,
  });

  bool get isToday {
    final now = DateTime.now();
    return date.year == now.year &&
        date.month == now.month &&
        date.day == now.day;
  }

  bool get hasEvents => events.isNotEmpty;
}
