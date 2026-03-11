import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import '../../design_system/colors.dart';
import '../../design_system/typography.dart';
import '../../models/email.dart';
import '../../services/auth_service.dart';
import '../../services/gmail_service.dart';
import '../../services/gemini_service.dart';
import '../../services/sound_service.dart';

enum ComposeMode { compose, reply, replyAll, forward }

/// Email composition with multi-account, AI drafts, speech-to-text,
/// AI subject generation, file/photo picker, and attachments
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
  final SoundService _sound = SoundService();

  bool _showCc = false;
  bool _showBcc = false;
  bool _isGeneratingDraft = false;
  bool _isSending = false;
  bool _showSchedule = false;
  DateTime? _scheduledDate;
  TimeOfDay? _scheduledTime;
  String? _selectedFromEmail;

  // New: Attachments
  final List<_AttachedFile> _attachedFiles = [];

  // New: Speech-to-text state
  bool _isRecording = false;

  // New: AI Subject generation
  bool _isGeneratingSubject = false;

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

  /// Generate AI subject from body content
  Future<void> _generateAISubject() async {
    if (_bodyController.text.isEmpty) return;
    setState(() => _isGeneratingSubject = true);
    final subject =
        await _gemini.generateEmailSubject(body: _bodyController.text);
    if (mounted && subject != null) {
      setState(() {
        _subjectController.text = subject;
        _isGeneratingSubject = false;
      });
    } else {
      setState(() => _isGeneratingSubject = false);
    }
  }

  /// Pick files to attach
  Future<void> _pickFiles() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        allowMultiple: true,
        type: FileType.any,
      );
      if (result != null && mounted) {
        setState(() {
          for (final file in result.files) {
            if (file.path != null) {
              _attachedFiles.add(_AttachedFile(
                name: file.name,
                path: file.path!,
                size: file.size,
                mimeType: _mimeTypeForExtension(file.extension ?? ''),
              ));
            }
          }
        });
      }
    } catch (e) {
      debugPrint('[ComposeView] File picker error: $e');
    }
  }

  /// Pick photos to attach
  Future<void> _pickPhotos() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        allowMultiple: true,
        type: FileType.image,
      );
      if (result != null && mounted) {
        setState(() {
          for (final file in result.files) {
            if (file.path != null) {
              _attachedFiles.add(_AttachedFile(
                name: file.name,
                path: file.path!,
                size: file.size,
                mimeType: _mimeTypeForExtension(file.extension ?? ''),
              ));
            }
          }
        });
      }
    } catch (e) {
      debugPrint('[ComposeView] Photo picker error: $e');
    }
  }

  /// Toggle speech-to-text recording (simulated)
  void _toggleRecording() {
    setState(() => _isRecording = !_isRecording);
    if (_isRecording) {
      _sound.playTapFeedback();
      // In production, would use speech_to_text package
      // For now, simulate recording state
      Future.delayed(const Duration(seconds: 5), () {
        if (mounted && _isRecording) {
          setState(() => _isRecording = false);
        }
      });
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
      if (success) {
        _sound.playSendSound();
        Navigator.pop(context);
      }
    }
  }

  String _mimeTypeForExtension(String ext) {
    const map = {
      'pdf': 'application/pdf',
      'jpg': 'image/jpeg',
      'jpeg': 'image/jpeg',
      'png': 'image/png',
      'gif': 'image/gif',
      'doc': 'application/msword',
      'docx':
          'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
      'xls': 'application/vnd.ms-excel',
      'xlsx':
          'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
      'pptx':
          'application/vnd.openxmlformats-officedocument.presentationml.presentation',
      'txt': 'text/plain',
      'csv': 'text/csv',
      'zip': 'application/zip',
      'mp4': 'video/mp4',
      'mp3': 'audio/mpeg',
      'html': 'text/html',
    };
    return map[ext.toLowerCase()] ?? 'application/octet-stream';
  }

  IconData _iconForMime(String mime) {
    if (mime.contains('pdf')) return Icons.picture_as_pdf;
    if (mime.contains('image')) return Icons.image;
    if (mime.contains('video')) return Icons.videocam;
    if (mime.contains('audio')) return Icons.audiotrack;
    if (mime.contains('spreadsheet') ||
        mime.contains('csv') ||
        mime.contains('excel')) {
      return Icons.table_chart;
    }
    if (mime.contains('word') || mime.contains('msword')) {
      return Icons.article;
    }
    if (mime.contains('presentation') || mime.contains('powerpoint')) {
      return Icons.slideshow;
    }
    if (mime.contains('zip') || mime.contains('compressed')) {
      return Icons.folder_zip;
    }
    if (mime.contains('text')) return Icons.text_snippet;
    return Icons.attach_file;
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
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

            // Title label with icon and subject
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      if (widget.mode == ComposeMode.reply || widget.mode == ComposeMode.replyAll)
                        const Padding(
                          padding: EdgeInsets.only(right: 10),
                          child: Icon(Icons.reply, size: 28, color: VoidColors.accentSkyBlue),
                        )
                      else if (widget.mode == ComposeMode.forward)
                        const Padding(
                          padding: EdgeInsets.only(right: 10),
                          child: Icon(Icons.forward, size: 28, color: VoidColors.accentPink),
                        ),
                      Text(
                        _headerTitle(),
                        style: Typo.headline.copyWith(fontSize: 26, fontWeight: FontWeight.w900),
                      ),
                    ],
                  ),
                  if (widget.replyTo != null) ...[
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Container(
                          width: 3,
                          height: 22,
                          decoration: BoxDecoration(
                            color: VoidColors.accentSkyBlue,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Re: ${widget.replyTo!.subject}',
                            style: Typo.subhead.copyWith(
                              fontSize: 18,
                              color: VoidColors.textTertiary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(height: 8),

            // Fields
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    // Fields container with rounded corners
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: VoidColors.bgSurface,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        children: [
                          // From selector
                          if (auth.accounts.length > 1) ...[
                            _buildFromSelector(auth),
                            const Divider(color: VoidColors.border, height: 0.5, indent: 20, endIndent: 20),
                          ],

                          // To + CC/BCC inline
                          _buildToFieldWithCcBcc(),

                          const Divider(color: VoidColors.border, height: 0.5, indent: 20, endIndent: 20),

                          if (_showCc) ...[
                            _buildField('CC', _ccController),
                            const Divider(color: VoidColors.border, height: 0.5, indent: 20, endIndent: 20),
                          ],
                          if (_showBcc) ...[
                            _buildField('BCC', _bccController),
                            const Divider(color: VoidColors.border, height: 0.5, indent: 20, endIndent: 20),
                          ],

                          // Subject
                          _buildField('SUBJ', _subjectController),
                        ],
                      ),
                    ),

                    const SizedBox(height: 8),

                    // Attached files
                    if (_attachedFiles.isNotEmpty) _buildAttachmentChips(),

                    // AI Drafting banner
                    if (_isGeneratingDraft) _buildAIDraftBanner(),

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

  String _headerTitle() {
    switch (widget.mode) {
      case ComposeMode.compose:
        return 'NEW MESSAGE';
      case ComposeMode.reply:
        return 'REPLY';
      case ComposeMode.replyAll:
        return 'REPLY ALL';
      case ComposeMode.forward:
        return 'FORWARD';
    }
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Row(
        children: [
          // Close button (left)
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: VoidColors.bgCard,
                shape: BoxShape.circle,
                border: Border.all(
                  color: VoidColors.border,
                  width: 1,
                ),
              ),
              child: const Center(
                child: Icon(Icons.close, size: 22, color: VoidColors.textSecondary),
              ),
            ),
          ),
          const Spacer(),
          // Send button (right)
          GestureDetector(
            onTap: _isSending ? null : _send,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              decoration: BoxDecoration(
                color: _toController.text.isNotEmpty
                    ? VoidColors.accentPink
                    : VoidColors.bgCardHover,
                borderRadius: BorderRadius.circular(24),
              ),
              child: _isSending
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: VoidColors.textInverse,
                      ),
                    )
                  : Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _showSchedule ? Icons.schedule_send : Icons.send,
                          size: 16,
                          color: _toController.text.isNotEmpty
                              ? VoidColors.textInverse
                              : VoidColors.textTertiary,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _showSchedule ? 'SCHEDULE' : 'SEND',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'monospace',
                            letterSpacing: 1.5,
                            color: _toController.text.isNotEmpty
                                ? VoidColors.textInverse
                                : VoidColors.textTertiary,
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
            child: Text(label, style: Typo.metaLabel.copyWith(fontSize: 15)),
          ),
          Expanded(
            child: TextField(
              controller: controller,
              style: Typo.body.copyWith(fontSize: 19),
              decoration: InputDecoration(
                border: InputBorder.none,
                filled: false,
                contentPadding: const EdgeInsets.symmetric(vertical: 14),
                hintStyle: Typo.body.copyWith(
                  fontSize: 19,
                  color: VoidColors.textTertiary,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildToFieldWithCcBcc() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 60,
            child: Text('TO', style: Typo.metaLabel.copyWith(fontSize: 15)),
          ),
          Expanded(
            child: TextField(
              controller: _toController,
              style: Typo.body.copyWith(fontSize: 19),
              decoration: InputDecoration(
                border: InputBorder.none,
                filled: false,
                contentPadding: const EdgeInsets.symmetric(vertical: 14),
                hintStyle: Typo.body.copyWith(
                  fontSize: 19,
                  color: VoidColors.textTertiary,
                ),
              ),
            ),
          ),
          if (!_showCc || !_showBcc)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (!_showCc)
                  GestureDetector(
                    onTap: () => setState(() => _showCc = true),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                      child: Text(
                        'CC',
                        style: Typo.metaLabel.copyWith(
                          fontSize: 17,
                          color: VoidColors.textTertiary,
                        ),
                      ),
                    ),
                  ),
                if (!_showCc && !_showBcc) const SizedBox(width: 8),
                if (!_showBcc)
                  GestureDetector(
                    onTap: () => setState(() => _showBcc = true),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                      child: Text(
                        'BCC',
                        style: Typo.metaLabel.copyWith(
                          fontSize: 17,
                          color: VoidColors.textTertiary,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
        ],
      ),
    );
  }

  /// Attachment chips (horizontal scroll)
  Widget _buildAttachmentChips() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Row(
        children: [
          ..._attachedFiles.asMap().entries.map((entry) {
            final index = entry.key;
            final file = entry.value;
            return Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              margin: const EdgeInsets.only(right: 8),
              decoration: BoxDecoration(
                color: VoidColors.bgCard,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _iconForMime(file.mimeType),
                    size: 15,
                    color: VoidColors.accentSkyBlue,
                  ),
                  const SizedBox(width: 6),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        file.name,
                        style: Typo.subhead.copyWith(
                          fontSize: 13,
                          color: VoidColors.textPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        _formatFileSize(file.size),
                        style: Typo.monoSmall,
                      ),
                    ],
                  ),
                  const SizedBox(width: 6),
                  GestureDetector(
                    onTap: () {
                      setState(() => _attachedFiles.removeAt(index));
                    },
                    child: const Icon(
                      Icons.cancel,
                      size: 16,
                      color: VoidColors.textTertiary,
                    ),
                  ),
                ],
              ),
            );
          }),
          // Add more button
          GestureDetector(
            onTap: _pickFiles,
            child: const Icon(
              Icons.add_circle_outline,
              size: 20,
              color: VoidColors.accentSkyBlue,
            ),
          ),
        ],
      ),
    );
  }

  /// AI Draft loading banner
  Widget _buildAIDraftBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 12),
      color: VoidColors.accentSkyBlue.withValues(alpha: 0.08),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: VoidColors.accentSkyBlue,
            ),
          ),
          const SizedBox(width: 10),
          Text(
            'AI IS DRAFTING...',
            style: Typo.mono.copyWith(
              color: VoidColors.accentSkyBlue,
              letterSpacing: 1,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSchedulePicker() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Column(
        children: [
          Row(
            children: [
              const Icon(Icons.schedule,
                  size: 18, color: VoidColors.accentYellow),
              const SizedBox(width: 8),
              Text(
                _scheduledDate != null
                    ? 'Scheduled: ${_scheduledDate!.month}/${_scheduledDate!.day}'
                        '${_scheduledTime != null ? ' ${_scheduledTime!.hour}:${_scheduledTime!.minute.toString().padLeft(2, '0')}' : ''}'
                    : 'Schedule Send',
                style: Typo.subhead.copyWith(
                  color: VoidColors.accentYellow,
                  fontSize: 14,
                ),
              ),
              const Spacer(),
              // Date picker
              GestureDetector(
                onTap: () async {
                  final date = await showDatePicker(
                    context: context,
                    initialDate:
                        DateTime.now().add(const Duration(hours: 1)),
                    firstDate: DateTime.now(),
                    lastDate:
                        DateTime.now().add(const Duration(days: 365)),
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
              const SizedBox(width: 12),
              // Time picker
              GestureDetector(
                onTap: () async {
                  final time = await showTimePicker(
                    context: context,
                    initialTime: TimeOfDay.now(),
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
                  if (time != null && mounted) {
                    setState(() => _scheduledTime = time);
                  }
                },
                child: const Icon(
                  Icons.access_time,
                  size: 18,
                  color: VoidColors.textTertiary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildToolbar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 10, 8, 70),
      decoration: const BoxDecoration(
        color: VoidColors.bgDeep,
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: VoidColors.bgCard,
          borderRadius: BorderRadius.circular(32),
        ),
        child: Row(
          children: [
            // AI Draft (capsule button)
            GestureDetector(
              onTap: _isGeneratingDraft ? null : _generateAIDraft,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: VoidColors.accentSkyBlue.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _isGeneratingDraft
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: VoidColors.accentSkyBlue,
                            ),
                          )
                        : const Icon(
                            Icons.auto_awesome,
                            size: 14,
                            color: VoidColors.accentSkyBlue,
                          ),
                    const SizedBox(width: 5),
                    Text(
                      'AI',
                      style: Typo.mono.copyWith(
                        color: VoidColors.accentSkyBlue,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const Spacer(),

            // Attach files
            _toolbarIcon(
              Icons.attach_file,
              color: _attachedFiles.isNotEmpty
                  ? VoidColors.accentSkyBlue
                  : VoidColors.textTertiary,
              onTap: _pickFiles,
            ),

            // Photos
            _toolbarIcon(
              Icons.photo,
              onTap: _pickPhotos,
            ),

            // Microphone (Speech to Text)
            _toolbarIcon(
              _isRecording ? Icons.mic : Icons.mic_none,
              color: _isRecording
                  ? VoidColors.accentPink
                  : VoidColors.textTertiary,
              onTap: _toggleRecording,
            ),

            // Magic wand (AI Subject)
            _toolbarIcon(
              Icons.auto_fix_high,
              color: _isGeneratingSubject
                  ? VoidColors.accentYellow
                  : VoidColors.textTertiary,
              onTap: _bodyController.text.isEmpty || _isGeneratingSubject
                  ? null
                  : _generateAISubject,
            ),

            // Schedule
            _toolbarIcon(
              _showSchedule ? Icons.schedule : Icons.schedule_outlined,
              color: _showSchedule
                  ? VoidColors.accentYellow
                  : VoidColors.textTertiary,
              onTap: () =>
                  setState(() => _showSchedule = !_showSchedule),
            ),

          ],
        ),
      ),
    );
  }

  Widget _toolbarIcon(
    IconData icon, {
    Color color = VoidColors.textTertiary,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: color != VoidColors.textTertiary
              ? color.withValues(alpha: 0.12)
              : Colors.transparent,
          shape: BoxShape.circle,
        ),
        child: Icon(icon, size: 22, color: color),
      ),
    );
  }
}

/// Attached file model
class _AttachedFile {
  final String name;
  final String path;
  final int size;
  final String mimeType;

  _AttachedFile({
    required this.name,
    required this.path,
    required this.size,
    required this.mimeType,
  });
}
