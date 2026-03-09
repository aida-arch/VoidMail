import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../design_system/colors.dart';
import '../../design_system/typography.dart';
import '../../design_system/components.dart';
import '../../models/calendar_event.dart';
import '../../services/calendar_service.dart';
import 'edit_event_sheet.dart';

class EventDetailSheet extends StatelessWidget {
  final CalendarEvent event;

  const EventDetailSheet({super.key, required this.event});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.9,
      decoration: const BoxDecoration(
        color: VoidColors.bgDeep,
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Column(
        children: [
          // Drag handle
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
                Text('EVENT DETAILS', style: Typo.metaLabel),
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

          // Content
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Color bar
                  Container(
                    width: double.infinity,
                    height: 4,
                    decoration: BoxDecoration(
                      color: event.color,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Title
                  Text(event.title, style: Typo.title2),

                  const SizedBox(height: 4),

                  // Calendar name
                  Text(
                    event.calendarName,
                    style: Typo.monoSmall.copyWith(
                      color: VoidColors.textTertiary,
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Date & Time
                  _buildInfoRow(
                    Icons.access_time,
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          DateFormat('EEEE, MMMM d, y').format(event.startDate),
                          style: Typo.body,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          event.timeRange,
                          style: Typo.monoSmall.copyWith(
                            color: event.color,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          event.duration,
                          style: Typo.caption.copyWith(
                            color: VoidColors.textTertiary,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Location
                  if (event.location != null) ...[
                    const SizedBox(height: 20),
                    _buildInfoRow(
                      Icons.location_on,
                      Text(event.location!, style: Typo.body),
                    ),
                  ],

                  // Meeting link
                  if (event.meetingPlatform != null) ...[
                    const SizedBox(height: 20),
                    _buildInfoRow(
                      Icons.videocam,
                      Row(
                        children: [
                          Text(
                            event.meetingPlatform!,
                            style: Typo.body.copyWith(color: event.color),
                          ),
                          const SizedBox(width: 12),
                          GestureDetector(
                            onTap: () => _launchMeetingLink(event.meetingLink!),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: event.color.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Text(
                                'JOIN',
                                style: Typo.metaLabel.copyWith(
                                  fontSize: 12,
                                  color: event.color,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  // Description
                  if (event.description != null &&
                      event.description!.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    _buildInfoRow(
                      Icons.notes,
                      Text(event.description!, style: Typo.body),
                    ),
                  ],

                  // Reminder
                  if (event.reminderMinutes != null) ...[
                    const SizedBox(height: 20),
                    _buildInfoRow(
                      Icons.notifications_outlined,
                      Text(
                        _reminderLabel(event.reminderMinutes!),
                        style: Typo.body,
                      ),
                    ),
                  ],

                  // Organizer
                  if (event.organizerEmail != null) ...[
                    const SizedBox(height: 24),
                    Text('ORGANIZER', style: Typo.metaLabel.copyWith(fontSize: 11)),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        InitialsAvatar(
                          name: event.organizerEmail!,
                          size: 32,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            event.organizerEmail!,
                            style: Typo.subhead,
                          ),
                        ),
                      ],
                    ),
                  ],

                  // Attendees
                  if (event.attendees.isNotEmpty) ...[
                    const SizedBox(height: 24),
                    Text(
                      'ATTENDEES (${event.attendees.length})',
                      style: Typo.metaLabel.copyWith(fontSize: 11),
                    ),
                    const SizedBox(height: 8),
                    ...event.attendees.map((email) => Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Row(
                            children: [
                              InitialsAvatar(name: email, size: 32),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(email, style: Typo.subhead),
                              ),
                            ],
                          ),
                        )),
                  ],

                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),

          // Bottom action bar
          Container(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
            decoration: const BoxDecoration(
              color: VoidColors.bgSurface,
              border: Border(
                top: BorderSide(color: VoidColors.border, width: 0.5),
              ),
            ),
            child: SafeArea(
              top: false,
              child: Row(
                children: [
                  Expanded(
                    child: VoidButton(
                      label: 'Edit',
                      icon: Icons.edit,
                      style: VoidButtonStyle.secondary,
                      onTap: () => _openEdit(context),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _DeleteButton(
                      onTap: () => _confirmDelete(context),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, Widget content) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: VoidColors.textSecondary),
        const SizedBox(width: 12),
        Expanded(child: content),
      ],
    );
  }

  String _reminderLabel(int minutes) {
    if (minutes < 60) return '$minutes minutes before';
    if (minutes == 60) return '1 hour before';
    if (minutes == 1440) return '1 day before';
    return '${minutes ~/ 60} hours before';
  }

  void _launchMeetingLink(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  void _openEdit(BuildContext context) async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => EditEventSheet(event: event),
    );
    if (result == true && context.mounted) {
      Navigator.pop(context);
    }
  }

  void _confirmDelete(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: VoidColors.bgCard,
        title: Text('Delete Event', style: Typo.headline),
        content: Text(
          'Are you sure you want to delete "${event.title}"?',
          style: Typo.body,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Cancel',
              style: TextStyle(color: VoidColors.textSecondary),
            ),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final success = await context
                  .read<CalendarService>()
                  .deleteEvent(event.id);
              if (success && context.mounted) {
                Navigator.pop(context);
              }
            },
            child: Text(
              'Delete',
              style: TextStyle(color: VoidColors.error),
            ),
          ),
        ],
      ),
    );
  }
}

class _DeleteButton extends StatefulWidget {
  final VoidCallback onTap;
  const _DeleteButton({required this.onTap});

  @override
  State<_DeleteButton> createState() => _DeleteButtonState();
}

class _DeleteButtonState extends State<_DeleteButton> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) {
        setState(() => _isPressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _isPressed = false),
      child: AnimatedScale(
        scale: _isPressed ? 0.95 : 1.0,
        duration: const Duration(milliseconds: 150),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          decoration: BoxDecoration(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: VoidColors.error.withValues(alpha: 0.5)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.delete_outline, size: 18, color: VoidColors.error),
              const SizedBox(width: 8),
              Text(
                'Delete',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: VoidColors.error,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
