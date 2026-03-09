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
  });

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
    );
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
