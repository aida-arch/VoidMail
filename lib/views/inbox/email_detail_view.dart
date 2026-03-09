import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../design_system/colors.dart';
import '../../design_system/typography.dart';
import '../../design_system/components.dart';
import '../../models/email.dart';
import '../../services/gmail_service.dart';
import '../../services/gemini_service.dart';
import '../compose/compose_view.dart';

/// Full email detail view with AI summary, translate, TTS, smart replies
class EmailDetailView extends StatefulWidget {
  final Email email;

  const EmailDetailView({super.key, required this.email});

  @override
  State<EmailDetailView> createState() => _EmailDetailViewState();
}

class _EmailDetailViewState extends State<EmailDetailView>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  final GeminiService _gemini = GeminiService();
  bool _isLoadingSummary = false;
  bool _isTranslating = false;
  String? _translatedBody;
  List<String> _smartReplies = [];

  // TTS
  bool _isPlaying = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    )..forward();

    _loadSmartReplies();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _generateSummary() async {
    setState(() => _isLoadingSummary = true);
    final summary = await _gemini.summarizeEmail(
      subject: widget.email.subject,
      body: widget.email.body,
      from: widget.email.from.displayName,
    );
    if (mounted) {
      setState(() {
        widget.email.aiSummary = summary;
        _isLoadingSummary = false;
      });
    }
  }

  Future<void> _translateEmail(String language) async {
    setState(() => _isTranslating = true);
    final translated = await _gemini.translateEmail(
      body: widget.email.body,
      targetLanguage: language,
    );
    if (mounted) {
      setState(() {
        _translatedBody = translated;
        _isTranslating = false;
      });
    }
  }

  Future<void> _loadSmartReplies() async {
    final replies = await _gemini.generateSmartReplies(
      from: widget.email.from.displayName,
      subject: widget.email.subject,
      body: widget.email.body,
    );
    if (mounted) {
      setState(() {
        _smartReplies = replies;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: VoidColors.bgDeep,
      body: SafeArea(
        child: Column(
          children: [
            // Top bar
            _buildTopBar(),

            // Scrollable content
            Expanded(
              child: FadeTransition(
                opacity: _controller,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 16),

                      // Subject
                      Text(
                        widget.email.subject,
                        style: Typo.title2,
                      ),
                      const SizedBox(height: 20),

                      // Sender info card
                      _buildSenderCard(),
                      const SizedBox(height: 16),

                      // AI Summary
                      AISummaryCard(
                        summary: widget.email.aiSummary,
                        isLoading: _isLoadingSummary,
                        onGenerate: _generateSummary,
                      ),
                      const SizedBox(height: 12),

                      // Action row: Translate, Listen
                      _buildActionRow(),
                      const SizedBox(height: 20),

                      // Email body
                      Text(
                        _translatedBody ?? widget.email.body,
                        style: Typo.body.copyWith(
                          height: 1.8,
                          color: VoidColors.textPrimary,
                        ),
                      ),

                      // Attachments
                      if (widget.email.attachments.isNotEmpty) ...[
                        const SizedBox(height: 24),
                        _buildAttachments(),
                      ],

                      // Smart Replies
                      if (_smartReplies.isNotEmpty) ...[
                        const SizedBox(height: 24),
                        _buildSmartReplies(),
                      ],

                      const SizedBox(height: 100),
                    ],
                  ),
                ),
              ),
            ),

            // Bottom action bar
            _buildBottomBar(),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.arrow_back, color: VoidColors.textPrimary),
          ),
          const Spacer(),
          IconButton(
            onPressed: () {
              final gmail = context.read<GmailService>();
              gmail.toggleStar(widget.email.id);
              setState(() {});
            },
            icon: Icon(
              widget.email.isStarred ? Icons.star : Icons.star_border,
              color: widget.email.isStarred
                  ? VoidColors.accentYellow
                  : VoidColors.textTertiary,
            ),
          ),
          IconButton(
            onPressed: () {
              context.read<GmailService>().archiveEmail(widget.email.id);
              Navigator.pop(context);
            },
            icon: const Icon(
              Icons.archive_outlined,
              color: VoidColors.textTertiary,
            ),
          ),
          IconButton(
            onPressed: () {
              context.read<GmailService>().deleteEmail(widget.email.id);
              Navigator.pop(context);
            },
            icon: const Icon(
              Icons.delete_outline,
              color: VoidColors.textTertiary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSenderCard() {
    return Row(
      children: [
        InitialsAvatar(
          name: widget.email.from.displayName,
          size: 44,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.email.from.displayName,
                style: Typo.headline,
              ),
              Text(
                widget.email.from.email,
                style: Typo.monoSmall,
              ),
            ],
          ),
        ),
        Text(
          DateFormat('MMM d, h:mm a').format(widget.email.date),
          style: Typo.monoSmall,
        ),
      ],
    );
  }

  Widget _buildActionRow() {
    return Row(
      children: [
        // Translate menu
        PopupMenuButton<String>(
          offset: const Offset(0, 40),
          color: VoidColors.bgCard,
          itemBuilder: (_) => [
            'Spanish',
            'French',
            'German',
            'Japanese',
            'Hindi',
            'Mandarin',
          ]
              .map((lang) => PopupMenuItem<String>(
                    value: lang,
                    child: Text(lang, style: Typo.body),
                  ))
              .toList(),
          onSelected: _translateEmail,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: VoidColors.bgCard,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: VoidColors.border, width: 0.5),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  _isTranslating ? Icons.hourglass_top : Icons.translate,
                  size: 16,
                  color: VoidColors.accentSkyBlue,
                ),
                const SizedBox(width: 6),
                Text(
                  _isTranslating ? 'Translating...' : 'Translate',
                  style: Typo.subhead.copyWith(
                    fontSize: 13,
                    color: VoidColors.accentSkyBlue,
                  ),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(width: 8),

        // Listen button (TTS)
        GestureDetector(
          onTap: () {
            setState(() => _isPlaying = !_isPlaying);
            // Simulated TTS progress
            if (_isPlaying) {
              _simulatePlayback();
            }
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: VoidColors.bgCard,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: VoidColors.border, width: 0.5),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  _isPlaying ? Icons.pause : Icons.volume_up,
                  size: 16,
                  color: VoidColors.accentGreen,
                ),
                const SizedBox(width: 6),
                Text(
                  _isPlaying ? 'Playing...' : 'Listen',
                  style: Typo.subhead.copyWith(
                    fontSize: 13,
                    color: VoidColors.accentGreen,
                  ),
                ),
              ],
            ),
          ),
        ),

        if (_translatedBody != null) ...[
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () => setState(() => _translatedBody = null),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: VoidColors.bgCard,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: VoidColors.border, width: 0.5),
              ),
              child: Text(
                'Original',
                style: Typo.subhead.copyWith(
                  fontSize: 13,
                  color: VoidColors.textSecondary,
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  void _simulatePlayback() async {
    for (int i = 0; i <= 100; i++) {
      await Future.delayed(const Duration(milliseconds: 100));
      if (!mounted || !_isPlaying) return;
      setState(() {});
    }
    if (mounted) setState(() => _isPlaying = false);
  }

  Widget _buildAttachments() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'ATTACHMENTS',
          style: Typo.metaLabel,
        ),
        const SizedBox(height: 12),
        ...widget.email.attachments.map((attachment) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: VoidCard(
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: VoidColors.bgSurface,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        attachment.icon,
                        size: 20,
                        color: VoidColors.accentSkyBlue,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            attachment.name,
                            style: Typo.body.copyWith(fontSize: 14),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            attachment.formattedSize,
                            style: Typo.monoSmall,
                          ),
                        ],
                      ),
                    ),
                    const Icon(
                      Icons.download,
                      size: 20,
                      color: VoidColors.textTertiary,
                    ),
                  ],
                ),
              ),
            )),
      ],
    );
  }

  Widget _buildSmartReplies() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(
              Icons.auto_awesome,
              size: 14,
              color: VoidColors.accentSkyBlue,
            ),
            const SizedBox(width: 6),
            Text(
              'SMART REPLIES',
              style: Typo.metaLabel.copyWith(
                color: VoidColors.accentSkyBlue,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _smartReplies.map((reply) {
            return GestureDetector(
              onTap: () => _openCompose(reply),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: VoidColors.bgCard,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: VoidColors.border, width: 0.5),
                ),
                child: Text(
                  reply,
                  style: Typo.subhead.copyWith(fontSize: 13),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildBottomBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
      decoration: const BoxDecoration(
        color: VoidColors.bgSurface,
        border: Border(
          top: BorderSide(color: VoidColors.border, width: 0.5),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildActionButton(
            Icons.reply,
            'Reply',
            () => _openCompose(null, mode: ComposeMode.reply),
          ),
          _buildActionButton(
            Icons.reply_all,
            'Reply All',
            () => _openCompose(null, mode: ComposeMode.replyAll),
          ),
          _buildActionButton(
            Icons.forward,
            'Forward',
            () => _openCompose(null, mode: ComposeMode.forward),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton(IconData icon, String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 22, color: VoidColors.textSecondary),
          const SizedBox(height: 4),
          Text(label, style: Typo.caption),
        ],
      ),
    );
  }

  void _openCompose(String? prefillBody, {ComposeMode mode = ComposeMode.reply}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => ComposeView(
        mode: mode,
        replyTo: widget.email,
        prefillBody: prefillBody,
      ),
    );
  }
}
