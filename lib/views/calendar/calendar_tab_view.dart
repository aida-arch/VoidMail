import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../design_system/colors.dart';
import '../../design_system/typography.dart';
import '../../design_system/components.dart';
import '../../models/calendar_event.dart';
import '../../services/calendar_service.dart';

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
        // Header
        ScreenHeader(
          metaLabel: DateFormat('yyyy').format(_currentMonth),
          title: 'CALENDAR',
        ),

        // Month navigation
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
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          Text(
            DateFormat('MMMM').format(_currentMonth).toUpperCase(),
            style: Typo.title3,
          ),
          const Spacer(),
          IconButton(
            onPressed: () {
              setState(() {
                _currentMonth = DateTime(
                    _currentMonth.year, _currentMonth.month - 1, 1);
              });
            },
            icon: const Icon(
              Icons.chevron_left,
              color: VoidColors.textSecondary,
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
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: VoidColors.border, width: 0.5),
              ),
              child: Text(
                'TODAY',
                style: Typo.metaLabel.copyWith(fontSize: 11),
              ),
            ),
          ),
          IconButton(
            onPressed: () {
              setState(() {
                _currentMonth = DateTime(
                    _currentMonth.year, _currentMonth.month + 1, 1);
              });
            },
            icon: const Icon(
              Icons.chevron_right,
              color: VoidColors.textSecondary,
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
                      style: Typo.metaLabel.copyWith(fontSize: 11),
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
              final hasEvents = calendarService.events
                  .any((e) => _isSameDay(e.startDate, date));

              return Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _selectedDate = date),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    height: 40,
                    margin: const EdgeInsets.all(1),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? VoidColors.textPrimary
                          : isToday
                              ? VoidColors.bgCard
                              : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          '${date.day}',
                          style: TextStyle(
                            fontSize: 14,
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
                        if (hasEvents)
                          Container(
                            width: 4,
                            height: 4,
                            margin: const EdgeInsets.only(top: 2),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? VoidColors.textInverse
                                  : VoidColors.accentPink,
                              shape: BoxShape.circle,
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

  @override
  Widget build(BuildContext context) {
    return VoidCard(
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Color bar
          Container(
            width: 4,
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
                  event.timeRange,
                  style: Typo.monoSmall.copyWith(
                    color: event.color,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  event.title,
                  style: Typo.headline.copyWith(fontSize: 16),
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
                      Text(
                        event.location!,
                        style: Typo.subhead.copyWith(fontSize: 13),
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
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: event.color.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Text(
                          'JOIN',
                          style: Typo.metaLabel.copyWith(
                            fontSize: 11,
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
