import 'package:flutter/foundation.dart';
import '../models/calendar_event.dart';
import '../design_system/colors.dart';
import 'backend_service.dart';

/// Google Calendar API Service
class CalendarService extends ChangeNotifier {
  final BackendService _backend = BackendService();

  List<CalendarEvent> _events = [];
  bool _isLoading = false;
  String? _error;

  List<CalendarEvent> get events => _events;
  bool get isLoading => _isLoading;
  String? get error => _error;

  /// Fetch events for a specific day
  Future<List<CalendarEvent>> fetchEvents(DateTime date) async {
    _isLoading = true;
    notifyListeners();

    try {
      final start = DateTime(date.year, date.month, date.day);
      final end = start.add(const Duration(days: 1));

      final response = await _backend.get('/api/calendar/events', queryParams: {
        'timeMin': start.toIso8601String(),
        'timeMax': end.toIso8601String(),
        'maxResults': '50',
      });

      final items = response['events'] as List? ?? response['data'] as List? ?? [];
      _events = items
          .map((e) => CalendarEvent.fromJson(e as Map<String, dynamic>))
          .toList();

      _events.sort((a, b) => a.startDate.compareTo(b.startDate));

      _isLoading = false;
      notifyListeners();
      return _events;
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      return [];
    }
  }

  /// Fetch events for a month
  Future<Map<DateTime, List<CalendarEvent>>> fetchMonthEvents(
      DateTime month) async {
    try {
      final start = DateTime(month.year, month.month, 1);
      final end = DateTime(month.year, month.month + 1, 0, 23, 59, 59);

      final response = await _backend.get('/api/calendar/events', queryParams: {
        'timeMin': start.toIso8601String(),
        'timeMax': end.toIso8601String(),
        'maxResults': '100',
      });

      final items = response['events'] as List? ?? response['data'] as List? ?? [];
      final events = items
          .map((e) => CalendarEvent.fromJson(e as Map<String, dynamic>))
          .toList();

      final Map<DateTime, List<CalendarEvent>> grouped = {};
      for (final event in events) {
        final dayKey = DateTime(
          event.startDate.year,
          event.startDate.month,
          event.startDate.day,
        );
        grouped.putIfAbsent(dayKey, () => []).add(event);
      }

      return grouped;
    } catch (e) {
      debugPrint('Error fetching month events: $e');
      return {};
    }
  }

  /// Create a new event
  Future<bool> createEvent({
    required String title,
    required DateTime start,
    required DateTime end,
    String? location,
    String? description,
    String? colorId,
    int? reminderMinutes,
    List<String>? attendees,
    bool addMeet = false,
  }) async {
    try {
      final body = <String, dynamic>{
        'summary': title,
        'start': start.toIso8601String(),
        'end': end.toIso8601String(),
        if (location != null) 'location': location,
        if (description != null) 'description': description,
        if (colorId != null) 'colorId': colorId,
        if (attendees != null) 'attendees': attendees,
        if (addMeet) 'conferenceRequest': true,
        if (reminderMinutes != null)
          'reminders': {
            'useDefault': false,
            'overrides': [
              {'method': 'popup', 'minutes': reminderMinutes}
            ],
          },
      };

      await _backend.post('/api/calendar/events', body: body);
      return true;
    } catch (e) {
      debugPrint('Error creating event: $e');
      return false;
    }
  }

  /// Update an existing event
  Future<bool> updateEvent({
    required String eventId,
    required String title,
    required DateTime start,
    required DateTime end,
    String? location,
    String? description,
    String? colorId,
    int? reminderMinutes,
    List<String>? attendees,
    bool addMeet = false,
  }) async {
    try {
      final body = <String, dynamic>{
        'summary': title,
        'start': start.toIso8601String(),
        'end': end.toIso8601String(),
        if (location != null) 'location': location,
        if (description != null) 'description': description,
        if (colorId != null) 'colorId': colorId,
        if (attendees != null) 'attendees': attendees,
        if (addMeet) 'conferenceRequest': true,
        if (reminderMinutes != null)
          'reminders': {
            'useDefault': false,
            'overrides': [
              {'method': 'popup', 'minutes': reminderMinutes}
            ],
          },
      };

      await _backend.put('/api/calendar/events/$eventId', body: body);

      // Update local cache
      final index = _events.indexWhere((e) => e.id == eventId);
      if (index != -1) {
        _events[index] = _events[index].copyWith(
          title: title,
          startDate: start,
          endDate: end,
          location: location,
          description: description,
          reminderMinutes: reminderMinutes,
        );
        _events.sort((a, b) => a.startDate.compareTo(b.startDate));
      }
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Error updating event: $e');
      return false;
    }
  }

  /// Delete an event
  Future<bool> deleteEvent(String eventId) async {
    try {
      await _backend.delete('/api/calendar/events/$eventId');
      _events.removeWhere((e) => e.id == eventId);
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Error deleting event: $e');
      return false;
    }
  }

  /// Load mock events for testing
  void loadMockEvents() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    _events = [
      CalendarEvent(
        id: 'e1',
        title: 'Team Standup',
        startDate: today.add(const Duration(hours: 9)),
        endDate: today.add(const Duration(hours: 9, minutes: 30)),
        meetingLink: 'https://meet.google.com/abc-defg-hij',
        color: VoidColors.accentSkyBlue,
        calendarName: 'Work',
      ),
      CalendarEvent(
        id: 'e2',
        title: 'Design Review',
        startDate: today.add(const Duration(hours: 11)),
        endDate: today.add(const Duration(hours: 12)),
        location: 'Conference Room B',
        color: VoidColors.accentPink,
        calendarName: 'Work',
        attendees: ['sarah@company.com', 'david@design.co'],
      ),
      CalendarEvent(
        id: 'e3',
        title: 'Lunch with Alex',
        startDate: today.add(const Duration(hours: 12, minutes: 30)),
        endDate: today.add(const Duration(hours: 13, minutes: 30)),
        location: 'Main Street Cafe',
        color: VoidColors.accentGreen,
        calendarName: 'Personal',
      ),
      CalendarEvent(
        id: 'e4',
        title: 'Sprint Planning',
        startDate: today.add(const Duration(hours: 14)),
        endDate: today.add(const Duration(hours: 15)),
        meetingLink: 'https://zoom.us/j/123456',
        color: VoidColors.accentYellow,
        calendarName: 'Work',
      ),
      CalendarEvent(
        id: 'e5',
        title: 'Product Demo',
        startDate: today.add(const Duration(hours: 16)),
        endDate: today.add(const Duration(hours: 17)),
        meetingLink: 'https://meet.google.com/xyz-uvwx-rst',
        color: VoidColors.accentSkyBlue,
        calendarName: 'Work',
        attendees: ['client@external.com', 'pm@company.com'],
      ),
    ];

    _isLoading = false;
    notifyListeners();
  }
}
