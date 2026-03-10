import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../design_system/colors.dart';
import '../../design_system/typography.dart';
import '../../design_system/components.dart';
import '../../models/email.dart';
import '../../services/gmail_service.dart';
import '../../services/gemini_service.dart';
import '../../services/deepgram_service.dart';
import '../../services/sound_service.dart';
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
  final DeepgramService _deepgram = DeepgramService();
  final SoundService _sound = SoundService();
  bool _isLoadingSummary = false;
  bool _isTranslating = false;
  String? _translatedBody;
  List<String> _smartReplies = [];

  // TTS
  bool _isPlaying = false;
  bool _isGeneratingAudio = false;

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

                      // Divider
                      Container(
                        height: 0.5,
                        color: VoidColors.border,
                      ),
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
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w400,
                          color: VoidColors.textSecondary,
                          height: 1.4,
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
              _sound.playStarSound();
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
              _sound.playDeleteSound();
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
              _sound.playDeleteSound();
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
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InitialsAvatar(
          name: widget.email.from.displayName,
          size: 48,
        ),
        const SizedBox(width: 14),
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
                style: Typo.mono.copyWith(
                  color: VoidColors.textTertiary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'TO ME',
                style: Typo.metaLabel.copyWith(
                  color: VoidColors.textTertiary,
                ),
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
      mainAxisAlignment: MainAxisAlignment.center,
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
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: VoidColors.accentPink.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  _isTranslating ? Icons.hourglass_top : Icons.language,
                  size: 16,
                  color: VoidColors.accentPink,
                ),
                const SizedBox(width: 6),
                Text(
                  _isTranslating ? 'TRANSLATING...' : 'AI TRANSLATE',
                  style: Typo.mono.copyWith(
                    fontSize: 13,
                    color: VoidColors.accentPink,
                  ),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(width: 8),

        // Listen button (TTS via Deepgram)
        GestureDetector(
          onTap: _toggleTTS,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: VoidColors.accentGreen.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: _isGeneratingAudio
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: VoidColors.accentGreen,
                    ),
                  )
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _isPlaying ? Icons.pause : Icons.play_arrow,
                        size: 16,
                        color: VoidColors.accentGreen,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        _isPlaying ? 'PAUSE' : 'LISTEN TO MAIL',
                        style: Typo.mono.copyWith(
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

  /// Toggle text-to-speech playback using Deepgram
  Future<void> _toggleTTS() async {
    if (_isPlaying) {
      await _deepgram.pause();
      setState(() => _isPlaying = false);
      return;
    }

    // Check for cached audio
    final cachedPath = _deepgram.cachedPath(widget.email.id);
    if (cachedPath != null) {
      await _deepgram.play(cachedPath);
      setState(() => _isPlaying = true);
      // Listen for playback completion
      _deepgram.addListener(_onTTSStateChanged);
      return;
    }

    // Generate audio
    setState(() => _isGeneratingAudio = true);
    final path = await _deepgram.generateAudio(
      emailId: widget.email.id,
      text: widget.email.body,
    );

    if (mounted && path != null) {
      setState(() => _isGeneratingAudio = false);
      await _deepgram.play(path);
      setState(() => _isPlaying = true);
      _deepgram.addListener(_onTTSStateChanged);
    } else if (mounted) {
      setState(() => _isGeneratingAudio = false);
    }
  }

  void _onTTSStateChanged() {
    if (mounted && !_deepgram.isPlaying && _isPlaying) {
      setState(() => _isPlaying = false);
      _deepgram.removeListener(_onTTSStateChanged);
    }
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
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: widget.email.attachments.map((attachment) {
              return Container(
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(right: 8),
                decoration: BoxDecoration(
                  color: VoidColors.bgCard,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      attachment.icon,
                      size: 16,
                      color: VoidColors.accentSkyBlue,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      attachment.name,
                      style: Typo.subhead.copyWith(fontSize: 13),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      attachment.formattedSize,
                      style: Typo.monoSmall,
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
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
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: _smartReplies.map((reply) {
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: GestureDetector(
                  onTap: () => _openCompose(reply),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: VoidColors.accentSkyBlue.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      reply,
                      style: Typo.subhead.copyWith(
                        fontSize: 13,
                        color: VoidColors.accentSkyBlue,
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildBottomBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      color: VoidColors.bgDeep,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildActionButton(
            Icons.reply,
            'Reply',
            VoidColors.accentSkyBlue,
            () => _openCompose(null, mode: ComposeMode.reply),
          ),
          _buildActionButton(
            Icons.reply_all,
            'Reply All',
            VoidColors.accentGreen,
            () => _openCompose(null, mode: ComposeMode.replyAll),
          ),
          _buildActionButton(
            Icons.forward,
            'Forward',
            VoidColors.accentPink,
            () => _openCompose(null, mode: ComposeMode.forward),
          ),
          _buildActionButton(
            widget.email.isStarred ? Icons.star : Icons.star_border,
            'Star',
            VoidColors.textSecondary,
            () {
              context.read<GmailService>().toggleStar(widget.email.id);
              setState(() {});
            },
          ),
          _buildActionButton(
            Icons.archive_outlined,
            'Archive',
            VoidColors.textSecondary,
            () {
              context.read<GmailService>().archiveEmail(widget.email.id);
              Navigator.pop(context);
            },
          ),
          _buildActionButton(
            Icons.delete_outline,
            'Delete',
            VoidColors.textSecondary,
            () {
              context.read<GmailService>().deleteEmail(widget.email.id);
              Navigator.pop(context);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton(
      IconData icon, String label, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 20, color: color),
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
