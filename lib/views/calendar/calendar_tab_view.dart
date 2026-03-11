import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../design_system/colors.dart';
import '../../design_system/typography.dart';
import '../../design_system/components.dart';
import '../../models/calendar_event.dart';
import '../../services/calendar_service.dart';
import 'event_detail_sheet.dart';

/// Calendar tab with monthly grid, event timeline, and event creation
class CalendarTabView extends StatefulWidget {
  const CalendarTabView({super.key});

  @override
  State<CalendarTabView> createState() => _CalendarTabViewState();
}

class _CalendarTabViewState extends State<CalendarTabView> {
  DateTime _currentMonth = DateTime.now();
  DateTime _selectedDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<CalendarService>().loadMockEvents();
    });
  }

  List<DateTime> _getDaysInMonth(DateTime month) {
    final first = DateTime(month.year, month.month, 1);

    // Pad start to make grid start on Monday
    final startWeekday = first.weekday; // 1=Mon, 7=Sun
    final startDate = first.subtract(Duration(days: startWeekday - 1));

    final days = <DateTime>[];
    var current = startDate;
    // Generate 6 weeks (42 days)
    for (int i = 0; i < 42; i++) {
      days.add(current);
      current = current.add(const Duration(days: 1));
    }
    return days;
  }

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  bool _isToday(DateTime date) => _isSameDay(date, DateTime.now());

  @override
  Widget build(BuildContext context) {
    final calendarService = context.watch<CalendarService>();
    final daysInMonth = _getDaysInMonth(_currentMonth);
    final selectedDayEvents = calendarService.events
        .where((e) => _isSameDay(e.startDate, _selectedDate))
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Month navigation (integrated header)
        _buildMonthNav(),

        const SizedBox(height: 12),

        // Day headers
        _buildDayHeaders(),

        const SizedBox(height: 8),

        // Calendar grid
        _buildCalendarGrid(daysInMonth, calendarService),

        const SizedBox(height: 16),

        // Selected day events
        Expanded(
          child: selectedDayEvents.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.event_available,
                        size: 40,
                        color: VoidColors.textTertiary,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'No events',
                        style: Typo.subhead,
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding:
                      const EdgeInsets.fromLTRB(20, 0, 20, 100),
                  itemCount: selectedDayEvents.length,
                  itemBuilder: (context, index) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child:
                          _EventCard(event: selectedDayEvents[index]),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildMonthNav() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Row(
        children: [
          Text(
            DateFormat('MMMM').format(_currentMonth).toUpperCase(),
            style: Typo.title2.copyWith(letterSpacing: -0.5),
          ),
          const Spacer(),
          GestureDetector(
            onTap: () {
              setState(() {
                _currentMonth = DateTime(
                    _currentMonth.year, _currentMonth.month - 1, 1);
              });
            },
            child: const Padding(
              padding: EdgeInsets.all(8),
              child: Icon(
                Icons.chevron_left,
                size: 16,
                color: VoidColors.textSecondary,
              ),
            ),
          ),
          GestureDetector(
            onTap: () {
              setState(() {
                _currentMonth = DateTime.now();
                _selectedDate = DateTime.now();
              });
            },
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: VoidColors.bgCard,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                'TODAY',
                style: Typo.mono.copyWith(
                  color: VoidColors.textPrimary,
                  letterSpacing: 1,
                ),
              ),
            ),
          ),
          GestureDetector(
            onTap: () {
              setState(() {
                _currentMonth = DateTime(
                    _currentMonth.year, _currentMonth.month + 1, 1);
              });
            },
            child: const Padding(
              padding: EdgeInsets.all(8),
              child: Icon(
                Icons.chevron_right,
                size: 16,
                color: VoidColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDayHeaders() {
    const days = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: days
            .map((d) => Expanded(
                  child: Center(
                    child: Text(
                      d,
                      style: Typo.mono.copyWith(
                        fontSize: 12,
                        color: VoidColors.textTertiary,
                      ),
                    ),
                  ),
                ))
            .toList(),
      ),
    );
  }

  Widget _buildCalendarGrid(
      List<DateTime> days, CalendarService calendarService) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: List.generate(6, (weekIndex) {
          return Row(
            children: List.generate(7, (dayIndex) {
              final date = days[weekIndex * 7 + dayIndex];
              final isCurrentMonth = date.month == _currentMonth.month;
              final isSelected = _isSameDay(date, _selectedDate);
              final isToday = _isToday(date);
              final dayEvents = calendarService.events
                  .where((e) => _isSameDay(e.startDate, date))
                  .toList();
              final eventColors = dayEvents
                  .map((e) => e.color)
                  .toSet()
                  .take(3)
                  .toList();

              return Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _selectedDate = date),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 36,
                    height: 44,
                    margin: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? VoidColors.textPrimary
                          : VoidColors.bgDeep,
                      borderRadius: BorderRadius.circular(8),
                      border: (!isSelected && isToday)
                          ? Border.all(
                              color: VoidColors.textPrimary, width: 1.5)
                          : null,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          '${date.day}',
                          style: TextStyle(
                            fontSize: 15,
                            fontFamily: 'monospace',
                            fontWeight: isToday || isSelected
                                ? FontWeight.bold
                                : FontWeight.w400,
                            color: isSelected
                                ? VoidColors.textInverse
                                : isCurrentMonth
                                    ? VoidColors.textPrimary
                                    : VoidColors.textTertiary,
                          ),
                        ),
                        if (eventColors.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: eventColors.map((color) {
                                return Container(
                                  width: 5,
                                  height: 5,
                                  margin: const EdgeInsets.symmetric(horizontal: 1),
                                  decoration: BoxDecoration(
                                    color: color,
                                    shape: BoxShape.circle,
                                  ),
                                );
                              }).toList(),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              );
            }),
          );
        }),
      ),
    );
  }
}

/// Event Card widget
class _EventCard extends StatelessWidget {
  final CalendarEvent event;

  const _EventCard({required this.event});

  String get _startTimeFormatted {
    final hour = event.startDate.hour;
    final minute = event.startDate.minute.toString().padLeft(2, '0');
    final period = hour >= 12 ? 'PM' : 'AM';
    final h = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
    return '$h:$minute $period';
  }

  @override
  Widget build(BuildContext context) {
    return VoidCard(
      color: const Color(0xFF1E1E1E),
      padding: const EdgeInsets.all(14),
      onTap: () {
        showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (context) => EventDetailSheet(event: event),
        );
      },
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Time column
          SizedBox(
            width: 65,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _startTimeFormatted,
                  style: Typo.mono.copyWith(
                    color: VoidColors.textSecondary,
                  ),
                ),
                Text(
                  event.duration,
                  style: Typo.monoSmall.copyWith(
                    color: VoidColors.textTertiary,
                  ),
                ),
              ],
            ),
          ),

          // Color bar
          Container(
            width: 3,
            height: 50,
            decoration: BoxDecoration(
              color: event.color,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 14),

          // Event details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  event.title,
                  style: Typo.headline,
                ),
                if (event.location != null) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(
                        Icons.location_on,
                        size: 14,
                        color: VoidColors.textTertiary,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          event.location!,
                          style: Typo.subhead.copyWith(fontSize: 13),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
                if (event.meetingPlatform != null) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(
                        Icons.videocam,
                        size: 14,
                        color: event.color,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        event.meetingPlatform!,
                        style: Typo.subhead.copyWith(
                          fontSize: 13,
                          color: event.color,
                        ),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: event.color.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'JOIN',
                          style: Typo.mono.copyWith(
                            fontSize: 12,
                            color: event.color,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
