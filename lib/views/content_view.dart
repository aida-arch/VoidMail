import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../design_system/colors.dart';
import '../design_system/typography.dart';
import '../design_system/components.dart';
import '../models/calendar_event.dart';
import '../services/calendar_service.dart';
import '../services/notification_service.dart';
import '../services/in_app_notification_manager.dart';
import 'inbox/inbox_view.dart';
import 'calendar/calendar_tab_view.dart';
import 'search/search_view.dart';
import 'settings/settings_view.dart';
import 'compose/compose_view.dart';
import 'ai/helix_o1_view.dart';
import 'shared/in_app_notification_banner.dart';

/// Main tab container with bottom nav, FAB, and tab transitions
class ContentView extends StatefulWidget {
  const ContentView({super.key});

  @override
  State<ContentView> createState() => _ContentViewState();
}

class _ContentViewState extends State<ContentView> {
  int _selectedTab = 0;
  final InAppNotificationManager _notificationManager =
      InAppNotificationManager();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: VoidColors.bgDeep,
      body: SafeArea(
        bottom: false,
        child: Stack(
          children: [
            // Tab content with crossfade transition
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              switchInCurve: Curves.easeInOut,
              switchOutCurve: Curves.easeInOut,
              child: _buildTabContent(),
            ),

            // FAB
            Positioned(
              right: 20,
              bottom: 110,
              child: _buildFAB(),
            ),

            // Bottom nav bar
            Positioned(
              left: 0,
              right: 0,
              bottom: 4,
              child: BottomNavBar(
                selectedIndex: _selectedTab,
                onTap: (index) => setState(() => _selectedTab = index),
                onComposeTap: _openCompose,
              ),
            ),

            // In-app notification banner overlay
            InAppNotificationBanner(
              manager: _notificationManager,
              onTap: (emailId) {
                // Navigate to inbox tab when banner tapped
                setState(() => _selectedTab = 0);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabContent() {
    switch (_selectedTab) {
      case 0:
        return InboxView(
          key: const ValueKey('inbox'),
          onHelixTap: _openHelix,
        );
      case 1:
        return const CalendarTabView(key: ValueKey('calendar'));
      case 2:
        return const SearchView(key: ValueKey('search'));
      case 3:
        return const SettingsView(key: ValueKey('settings'));
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildFAB() {
    // Compose moved to nav bar; keep calendar FAB as floating
    if (_selectedTab == 1) {
      return MonochromeFAB(
        key: const ValueKey('calendar_fab'),
        icon: Icons.add,
        color: VoidColors.accentSand,
        onTap: _openCreateEvent,
      );
    }
    return const SizedBox.shrink();
  }

  void _openCompose() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const ComposeView(),
    );
  }

  void _openHelix() {
    Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            const HelixO1View(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(
            opacity: animation,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, 0.05),
                end: Offset.zero,
              ).animate(CurvedAnimation(
                parent: animation,
                curve: Curves.easeOutCubic,
              )),
              child: child,
            ),
          );
        },
        transitionDuration: const Duration(milliseconds: 350),
      ),
    );
  }

  void _openCreateEvent() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _CreateEventSheet(),
    );
  }
}

/// Create Event Bottom Sheet
class _CreateEventSheet extends StatefulWidget {
  @override
  State<_CreateEventSheet> createState() => _CreateEventSheetState();
}

class _CreateEventSheetState extends State<_CreateEventSheet> {
  final _titleController = TextEditingController();
  final _locationController = TextEditingController();
  final _descriptionController = TextEditingController();
  DateTime _startDate = DateTime.now().add(const Duration(hours: 1));
  DateTime _endDate = DateTime.now().add(const Duration(hours: 2));
  bool _addMeet = false;
  Color _selectedColor = VoidColors.accentSkyBlue;
  int? _reminderMinutes;
  bool _isSaving = false;

  @override
  void dispose() {
    _titleController.dispose();
    _locationController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.8,
      decoration: const BoxDecoration(
        color: VoidColors.bgDeep,
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Column(
        children: [
          // Handle
          Container(
            margin: const EdgeInsets.only(top: 8),
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: VoidColors.border,
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 8, 8),
            child: Row(
              children: [
                Text('NEW EVENT', style: Typo.metaLabel),
                const Spacer(),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close,
                      color: VoidColors.textTertiary),
                ),
              ],
            ),
          ),

          const Divider(color: VoidColors.border, height: 0.5),

          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title (hero size)
                  TextField(
                    controller: _titleController,
                    style: Typo.title2.copyWith(fontSize: 28),
                    decoration: InputDecoration(
                      hintText: 'Event title',
                      hintStyle: Typo.title2.copyWith(
                        fontSize: 28,
                        color: VoidColors.textTertiary,
                      ),
                      border: InputBorder.none,
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Date/time
                  _buildDateTimeRow('START', _startDate, (d) {
                    setState(() => _startDate = d);
                  }),
                  const SizedBox(height: 12),
                  _buildDateTimeRow('END', _endDate, (d) {
                    setState(() => _endDate = d);
                  }),

                  const SizedBox(height: 24),

                  // Google Meet toggle
                  Row(
                    children: [
                      const Icon(Icons.videocam,
                          size: 20, color: VoidColors.textSecondary),
                      const SizedBox(width: 12),
                      Text('Add Google Meet', style: Typo.body),
                      const Spacer(),
                      Switch(
                        value: _addMeet,
                        onChanged: (v) => setState(() => _addMeet = v),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // Location
                  TextField(
                    controller: _locationController,
                    style: Typo.body,
                    decoration: InputDecoration(
                      hintText: 'Add location',
                      hintStyle: Typo.body.copyWith(
                        color: VoidColors.textTertiary,
                      ),
                      prefixIcon: const Icon(
                        Icons.location_on,
                        size: 20,
                        color: VoidColors.textSecondary,
                      ),
                      border: InputBorder.none,
                    ),
                  ),

                  const SizedBox(height: 8),

                  // Description
                  TextField(
                    controller: _descriptionController,
                    style: Typo.body,
                    maxLines: 3,
                    decoration: InputDecoration(
                      hintText: 'Add description',
                      hintStyle: Typo.body.copyWith(
                        color: VoidColors.textTertiary,
                      ),
                      prefixIcon: const Icon(
                        Icons.notes,
                        size: 20,
                        color: VoidColors.textSecondary,
                      ),
                      border: InputBorder.none,
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Color picker
                  _buildColorPicker(),

                  const SizedBox(height: 8),

                  // Reminder
                  _buildReminderDropdown(),
                ],
              ),
            ),
          ),

          // Save button
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
            child: VoidButton(
              label: 'Create Event',
              icon: Icons.check,
              isLoading: _isSaving,
              onTap: _create,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildColorPicker() {
    final colors = [
      VoidColors.accentSkyBlue,
      VoidColors.accentGreen,
      const Color(0xFF9966CC),
      VoidColors.accentPink,
      VoidColors.accentYellow,
    ];
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('COLOR', style: Typo.metaLabel.copyWith(fontSize: 11)),
          const SizedBox(height: 12),
          Row(
            children: colors.map((color) {
              final isSelected = color.toARGB32() == _selectedColor.toARGB32();
              return GestureDetector(
                onTap: () => setState(() => _selectedColor = color),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 36,
                  height: 36,
                  margin: const EdgeInsets.only(right: 12),
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                    border: isSelected
                        ? Border.all(color: VoidColors.textPrimary, width: 2)
                        : null,
                  ),
                  child: isSelected
                      ? const Icon(Icons.check,
                          size: 18, color: VoidColors.textInverse)
                      : null,
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildReminderDropdown() {
    final options = <int?>[null, 5, 15, 30, 60, 1440];
    final labels = <int?, String>{
      null: 'None',
      5: '5 minutes before',
      15: '15 minutes before',
      30: '30 minutes before',
      60: '1 hour before',
      1440: '1 day before',
    };

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          const Icon(Icons.notifications_outlined,
              size: 20, color: VoidColors.textSecondary),
          const SizedBox(width: 12),
          Text('Reminder', style: Typo.body),
          const Spacer(),
          DropdownButton<int?>(
            value: _reminderMinutes,
            dropdownColor: VoidColors.bgCard,
            underline: const SizedBox(),
            style: Typo.subhead.copyWith(fontSize: 14),
            items: options
                .map((val) => DropdownMenuItem<int?>(
                      value: val,
                      child: Text(labels[val]!,
                          style: Typo.subhead.copyWith(fontSize: 14)),
                    ))
                .toList(),
            onChanged: (val) => setState(() => _reminderMinutes = val),
          ),
        ],
      ),
    );
  }

  Future<void> _create() async {
    if (_titleController.text.trim().isEmpty) return;

    setState(() => _isSaving = true);

    final colorId = CalendarEvent(
      id: '',
      title: '',
      startDate: DateTime.now(),
      endDate: DateTime.now(),
      color: _selectedColor,
    ).colorId;

    final success =
        await context.read<CalendarService>().createEvent(
              title: _titleController.text.trim(),
              start: _startDate,
              end: _endDate,
              location: _locationController.text.trim().isNotEmpty
                  ? _locationController.text.trim()
                  : null,
              description: _descriptionController.text.trim().isNotEmpty
                  ? _descriptionController.text.trim()
                  : null,
              colorId: colorId,
              reminderMinutes: _reminderMinutes,
              addMeet: _addMeet,
            );

    if (success && _reminderMinutes != null) {
      NotificationService().scheduleEventReminder(
        eventId: 'new_${DateTime.now().millisecondsSinceEpoch}',
        title: _titleController.text.trim(),
        timeRange:
            '${_startDate.hour}:${_startDate.minute.toString().padLeft(2, '0')}',
        eventStart: _startDate,
        minutesBefore: _reminderMinutes!,
      );
    }

    setState(() => _isSaving = false);

    if (success && mounted) {
      Navigator.pop(context);
    }
  }

  Widget _buildDateTimeRow(
      String label, DateTime date, ValueChanged<DateTime> onChanged) {
    return GestureDetector(
      onTap: () async {
        final ctx = context;
        final picked = await showDatePicker(
          context: ctx,
          initialDate: date,
          firstDate: DateTime.now(),
          lastDate: DateTime.now().add(const Duration(days: 365)),
          builder: (context, child) {
            return Theme(
              data: ThemeData.dark().copyWith(
                colorScheme: const ColorScheme.dark(
                  primary: VoidColors.accentPink,
                  surface: VoidColors.bgCard,
                ),
              ),
              child: child!,
            );
          },
        );
        if (picked != null && ctx.mounted) {
          final time = await showTimePicker(
            context: ctx,
            initialTime: TimeOfDay.fromDateTime(date),
            builder: (context, child) {
              return Theme(
                data: ThemeData.dark().copyWith(
                  colorScheme: const ColorScheme.dark(
                    primary: VoidColors.accentPink,
                    surface: VoidColors.bgCard,
                  ),
                ),
                child: child!,
              );
            },
          );
          if (time != null) {
            onChanged(DateTime(
              picked.year,
              picked.month,
              picked.day,
              time.hour,
              time.minute,
            ));
          }
        }
      },
      child: Row(
        children: [
          Text(label, style: Typo.metaLabel.copyWith(fontSize: 11)),
          const SizedBox(width: 12),
          Text(
            '${date.month}/${date.day}/${date.year}  ${date.hour}:${date.minute.toString().padLeft(2, '0')}',
            style: Typo.mono,
          ),
        ],
      ),
    );
  }
}
