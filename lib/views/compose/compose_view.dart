import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../design_system/colors.dart';
import '../../design_system/typography.dart';
import '../../models/email.dart';
import '../../services/auth_service.dart';
import '../../services/gmail_service.dart';
import '../../services/gemini_service.dart';

enum ComposeMode { compose, reply, replyAll, forward }

/// Email composition with multi-account, AI drafts, attachments
class ComposeView extends StatefulWidget {
  final ComposeMode mode;
  final Email? replyTo;
  final String? prefillBody;

  const ComposeView({
    super.key,
    this.mode = ComposeMode.compose,
    this.replyTo,
    this.prefillBody,
  });

  @override
  State<ComposeView> createState() => _ComposeViewState();
}

class _ComposeViewState extends State<ComposeView>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  final _toController = TextEditingController();
  final _ccController = TextEditingController();
  final _bccController = TextEditingController();
  final _subjectController = TextEditingController();
  final _bodyController = TextEditingController();
  final GeminiService _gemini = GeminiService();

  bool _showCc = false;
  bool _showBcc = false;
  bool _isGeneratingDraft = false;
  bool _isSending = false;
  bool _showSchedule = false;
  DateTime? _scheduledDate;
  String? _selectedFromEmail;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    )..forward();

    _prefillFields();
    if (widget.prefillBody != null) {
      _bodyController.text = widget.prefillBody!;
    }
  }

  void _prefillFields() {
    if (widget.replyTo == null) return;

    switch (widget.mode) {
      case ComposeMode.reply:
        _toController.text = widget.replyTo!.from.email;
        _subjectController.text = 'Re: ${widget.replyTo!.subject}';
        break;
      case ComposeMode.replyAll:
        _toController.text = widget.replyTo!.from.email;
        _ccController.text =
            widget.replyTo!.cc.map((c) => c.email).join(', ');
        _subjectController.text = 'Re: ${widget.replyTo!.subject}';
        _showCc = _ccController.text.isNotEmpty;
        break;
      case ComposeMode.forward:
        _subjectController.text = 'Fwd: ${widget.replyTo!.subject}';
        _bodyController.text =
            '\n\n---------- Forwarded message ----------\n'
            'From: ${widget.replyTo!.from.displayName} <${widget.replyTo!.from.email}>\n'
            'Subject: ${widget.replyTo!.subject}\n\n'
            '${widget.replyTo!.body}';
        break;
      case ComposeMode.compose:
        break;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _toController.dispose();
    _ccController.dispose();
    _bccController.dispose();
    _subjectController.dispose();
    _bodyController.dispose();
    super.dispose();
  }

  Future<void> _generateAIDraft() async {
    setState(() => _isGeneratingDraft = true);
    final draft = await _gemini.generateDraft(
      context: _subjectController.text.isEmpty
          ? 'Write a professional email'
          : _subjectController.text,
      replyTo: widget.replyTo != null
          ? {
              'from': widget.replyTo!.from.displayName,
              'subject': widget.replyTo!.subject,
              'body': widget.replyTo!.body,
            }
          : null,
    );
    if (mounted && draft != null) {
      setState(() {
        _bodyController.text = draft;
        _isGeneratingDraft = false;
      });
    } else {
      setState(() => _isGeneratingDraft = false);
    }
  }

  Future<void> _send() async {
    if (_toController.text.isEmpty) return;
    setState(() => _isSending = true);

    final gmail = context.read<GmailService>();
    final success = await gmail.sendEmail(
      to: _toController.text,
      subject: _subjectController.text,
      body: _bodyController.text,
      replyToId: widget.replyTo?.id,
      threadId: widget.replyTo?.threadId,
      fromEmail: _selectedFromEmail,
    );

    if (mounted) {
      setState(() => _isSending = false);
      if (success) Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();

    return SlideTransition(
      position: Tween<Offset>(
        begin: const Offset(0, 1),
        end: Offset.zero,
      ).animate(CurvedAnimation(
        parent: _controller,
        curve: Curves.easeOutCubic,
      )),
      child: Container(
        height: MediaQuery.of(context).size.height * 0.92,
        decoration: const BoxDecoration(
          color: VoidColors.bgDeep,
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        child: Column(
          children: [
            // Handle bar
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
            _buildHeader(),

            const Divider(color: VoidColors.border, height: 0.5),

            // Fields
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    // From selector
                    if (auth.accounts.length > 1) _buildFromSelector(auth),

                    // To
                    _buildField('TO', _toController),

                    // CC/BCC toggles
                    if (!_showCc || !_showBcc) _buildCcBccToggle(),

                    if (_showCc) _buildField('CC', _ccController),
                    if (_showBcc) _buildField('BCC', _bccController),

                    // Subject
                    _buildField('SUBJECT', _subjectController),

                    const Divider(color: VoidColors.border, height: 0.5),

                    // Body
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: TextField(
                        controller: _bodyController,
                        maxLines: null,
                        minLines: 10,
                        style: Typo.body.copyWith(height: 1.8),
                        decoration: InputDecoration(
                          hintText: 'Compose your email...',
                          hintStyle: Typo.body.copyWith(
                            color: VoidColors.textTertiary,
                          ),
                          border: InputBorder.none,
                          filled: false,
                        ),
                      ),
                    ),

                    // Schedule
                    if (_showSchedule) _buildSchedulePicker(),
                  ],
                ),
              ),
            ),

            // Bottom toolbar
            _buildToolbar(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    String title;
    switch (widget.mode) {
      case ComposeMode.compose:
        title = 'NEW MESSAGE';
        break;
      case ComposeMode.reply:
        title = 'REPLY';
        break;
      case ComposeMode.replyAll:
        title = 'REPLY ALL';
        break;
      case ComposeMode.forward:
        title = 'FORWARD';
        break;
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 8, 12),
      child: Row(
        children: [
          Text(title, style: Typo.metaLabel),
          const Spacer(),
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.close, color: VoidColors.textTertiary),
          ),
        ],
      ),
    );
  }

  Widget _buildFromSelector(AuthService auth) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      child: Row(
        children: [
          SizedBox(
            width: 60,
            child: Text('FROM', style: Typo.metaLabel.copyWith(fontSize: 11)),
          ),
          Expanded(
            child: DropdownButton<String>(
              value: _selectedFromEmail ?? auth.currentUser?.email,
              isExpanded: true,
              dropdownColor: VoidColors.bgCard,
              underline: const SizedBox(),
              style: Typo.body.copyWith(fontSize: 14),
              items: auth.accounts
                  .map((a) => DropdownMenuItem(
                        value: a.email,
                        child: Text(
                          '${a.label} (${a.email})',
                          style: Typo.body.copyWith(fontSize: 14),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ))
                  .toList(),
              onChanged: (val) => setState(() => _selectedFromEmail = val),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildField(String label, TextEditingController controller) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 60,
            child: Text(label, style: Typo.metaLabel.copyWith(fontSize: 11)),
          ),
          Expanded(
            child: TextField(
              controller: controller,
              style: Typo.body.copyWith(fontSize: 15),
              decoration: InputDecoration(
                border: InputBorder.none,
                filled: false,
                contentPadding:
                    const EdgeInsets.symmetric(vertical: 14),
                hintStyle: Typo.body.copyWith(
                  fontSize: 15,
                  color: VoidColors.textTertiary,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCcBccToggle() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(80, 0, 20, 0),
      child: Row(
        children: [
          if (!_showCc)
            GestureDetector(
              onTap: () => setState(() => _showCc = true),
              child: Text(
                'CC',
                style: Typo.subhead.copyWith(
                  fontSize: 13,
                  color: VoidColors.accentSkyBlue,
                ),
              ),
            ),
          if (!_showCc && !_showBcc) const SizedBox(width: 16),
          if (!_showBcc)
            GestureDetector(
              onTap: () => setState(() => _showBcc = true),
              child: Text(
                'BCC',
                style: Typo.subhead.copyWith(
                  fontSize: 13,
                  color: VoidColors.accentSkyBlue,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSchedulePicker() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        children: [
          const Icon(Icons.schedule, size: 18, color: VoidColors.accentYellow),
          const SizedBox(width: 8),
          Text(
            _scheduledDate != null
                ? 'Scheduled: ${_scheduledDate!.month}/${_scheduledDate!.day} ${_scheduledDate!.hour}:${_scheduledDate!.minute.toString().padLeft(2, '0')}'
                : 'Schedule Send',
            style: Typo.subhead.copyWith(
              color: VoidColors.accentYellow,
              fontSize: 14,
            ),
          ),
          const Spacer(),
          GestureDetector(
            onTap: () async {
              final date = await showDatePicker(
                context: context,
                initialDate: DateTime.now().add(const Duration(hours: 1)),
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
              if (date != null && mounted) {
                setState(() => _scheduledDate = date);
              }
            },
            child: const Icon(
              Icons.edit_calendar,
              size: 18,
              color: VoidColors.textTertiary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildToolbar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
      decoration: const BoxDecoration(
        color: VoidColors.bgSurface,
        border: Border(
          top: BorderSide(color: VoidColors.border, width: 0.5),
        ),
      ),
      child: Row(
        children: [
          // AI Draft
          IconButton(
            onPressed: _isGeneratingDraft ? null : _generateAIDraft,
            icon: _isGeneratingDraft
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: VoidColors.accentSkyBlue,
                    ),
                  )
                : const Icon(
                    Icons.auto_awesome,
                    size: 20,
                    color: VoidColors.accentSkyBlue,
                  ),
          ),

          // Schedule
          IconButton(
            onPressed: () => setState(() => _showSchedule = !_showSchedule),
            icon: Icon(
              Icons.schedule,
              size: 20,
              color: _showSchedule
                  ? VoidColors.accentYellow
                  : VoidColors.textTertiary,
            ),
          ),

          // Attach
          IconButton(
            onPressed: () {
              // File picker
            },
            icon: const Icon(
              Icons.attach_file,
              size: 20,
              color: VoidColors.textTertiary,
            ),
          ),

          const Spacer(),

          // Send button
          GestureDetector(
            onTap: _isSending ? null : _send,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              decoration: BoxDecoration(
                color: VoidColors.accentPink,
                borderRadius: BorderRadius.circular(24),
              ),
              child: _isSending
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: VoidColors.textInverse,
                      ),
                    )
                  : Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.send,
                          size: 16,
                          color: VoidColors.textInverse,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Send',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: VoidColors.textInverse,
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
}
