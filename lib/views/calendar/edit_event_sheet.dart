import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../design_system/colors.dart';
import '../../design_system/typography.dart';
import '../../design_system/components.dart';
import '../../models/calendar_event.dart';
import '../../services/calendar_service.dart';
import '../../services/notification_service.dart';

class EditEventSheet extends StatefulWidget {
  final CalendarEvent event;

  const EditEventSheet({super.key, required this.event});

  @override
  State<EditEventSheet> createState() => _EditEventSheetState();
}

class _EditEventSheetState extends State<EditEventSheet> {
  late TextEditingController _titleController;
  late TextEditingController _locationController;
  late TextEditingController _descriptionController;
  late DateTime _startDate;
  late DateTime _endDate;
  late Color _selectedColor;
  late bool _addMeet;
  int? _reminderMinutes;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.event.title);
    _locationController =
        TextEditingController(text: widget.event.location ?? '');
    _descriptionController =
        TextEditingController(text: widget.event.description ?? '');
    _startDate = widget.event.startDate;
    _endDate = widget.event.endDate;
    _selectedColor = widget.event.color;
    _addMeet = widget.event.meetingLink != null;
    _reminderMinutes = widget.event.reminderMinutes;
  }

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
                Text('EDIT EVENT', style: Typo.metaLabel),
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
                  // Title
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
                      hintStyle:
                          Typo.body.copyWith(color: VoidColors.textTertiary),
                      prefixIcon: const Icon(Icons.location_on,
                          size: 20, color: VoidColors.textSecondary),
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
                      hintStyle:
                          Typo.body.copyWith(color: VoidColors.textTertiary),
                      prefixIcon: const Icon(Icons.notes,
                          size: 20, color: VoidColors.textSecondary),
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
              label: 'Save Changes',
              icon: Icons.check,
              isLoading: _isSaving,
              onTap: _save,
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

  Widget _buildDateTimeRow(
      String label, DateTime date, ValueChanged<DateTime> onChanged) {
    return GestureDetector(
      onTap: () async {
        final ctx = context;
        final picked = await showDatePicker(
          context: ctx,
          initialDate: date,
          firstDate: DateTime.now().subtract(const Duration(days: 365)),
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

  Future<void> _save() async {
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
        await context.read<CalendarService>().updateEvent(
              eventId: widget.event.id,
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

    // Schedule reminder notification if set
    if (success && _reminderMinutes != null) {
      NotificationService().scheduleEventReminder(
        eventId: widget.event.id,
        title: _titleController.text.trim(),
        timeRange: '${_startDate.hour}:${_startDate.minute.toString().padLeft(2, '0')}',
        eventStart: _startDate,
        minutesBefore: _reminderMinutes!,
      );
    }

    setState(() => _isSaving = false);

    if (success && mounted) {
      Navigator.pop(context, true);
    }
  }
}
