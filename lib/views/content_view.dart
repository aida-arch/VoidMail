import 'package:flutter/material.dart';
import '../design_system/colors.dart';
import '../design_system/typography.dart';
import '../design_system/components.dart';
import 'inbox/inbox_view.dart';
import 'calendar/calendar_tab_view.dart';
import 'search/search_view.dart';
import 'settings/settings_view.dart';
import 'compose/compose_view.dart';
import 'ai/helix_o1_view.dart';

/// Main tab container with bottom nav, FAB, and tab transitions
class ContentView extends StatefulWidget {
  const ContentView({super.key});

  @override
  State<ContentView> createState() => _ContentViewState();
}

class _ContentViewState extends State<ContentView> {
  int _selectedTab = 0;

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
              ),
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
    // Pink compose for inbox, sand calendar button for calendar tab
    if (_selectedTab == 0) {
      return MonochromeFAB(
        key: const ValueKey('inbox_fab'),
        icon: Icons.edit,
        color: VoidColors.accentPink,
        onTap: _openCompose,
      );
    } else if (_selectedTab == 1) {
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
  DateTime _startDate = DateTime.now().add(const Duration(hours: 1));
  DateTime _endDate = DateTime.now().add(const Duration(hours: 2));
  bool _addMeet = false;

  @override
  void dispose() {
    _titleController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
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
              onTap: () {
                // Create event logic
                Navigator.pop(context);
              },
            ),
          ),
        ],
      ),
    );
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
          SizedBox(
            width: 50,
            child: Text(label, style: Typo.metaLabel.copyWith(fontSize: 11)),
          ),
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
