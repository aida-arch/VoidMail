import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
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
  String? _translateError;
  List<String> _smartReplies = [];

  // Full email body (fetched on demand if metadata-only)
  String? _fullBody;
  bool _isLoadingBody = false;

  /// Best available body text (full if loaded, otherwise whatever we have)
  String get _displayBody =>
      _fullBody ?? (widget.email.body.isEmpty ? widget.email.snippet : widget.email.body);

  // TTS
  bool _isPlaying = false;
  bool _isGeneratingAudio = false;

  // Attachment download state
  final Set<String> _downloadingAttachments = {};
  final Map<String, String> _downloadedPaths = {};

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    )..forward();

    _fetchFullBody();
    _loadAISummary();
    _loadSmartReplies();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Fetch full email body if we only have metadata/snippet
  Future<void> _fetchFullBody() async {
    if (widget.email.body.isNotEmpty) return; // Already have body
    setState(() => _isLoadingBody = true);
    try {
      final gmail = context.read<GmailService>();
      final full = await gmail.fetchEmailDetail(widget.email.id);
      if (mounted && full != null && full.body.isNotEmpty) {
        setState(() {
          _fullBody = full.body;
          _isLoadingBody = false;
        });
      } else if (mounted) {
        setState(() => _isLoadingBody = false);
      }
    } catch (e) {
      debugPrint('[EmailDetail] Error fetching full body: $e');
      if (mounted) setState(() => _isLoadingBody = false);
    }
  }

  /// Auto-generate AI summary on load (matching reference behavior)
  Future<void> _loadAISummary() async {
    // Skip if already have a cached summary
    if (widget.email.aiSummary != null) return;

    // Wait for full body to load first
    if (_isLoadingBody) {
      for (var i = 0; i < 30; i++) {
        if (!_isLoadingBody) break;
        await Future.delayed(const Duration(milliseconds: 100));
      }
    }

    setState(() => _isLoadingSummary = true);
    final summary = await _gemini.summarizeEmail(
      subject: widget.email.subject,
      body: _displayBody,
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
    setState(() {
      _isTranslating = true;
      _translateError = null;
    });

    // Wait for body to load if still fetching (matching reference behavior)
    if (_isLoadingBody) {
      for (var i = 0; i < 30; i++) {
        if (!_isLoadingBody) break;
        await Future.delayed(const Duration(milliseconds: 100));
      }
    }

    // Use best available text
    final textToTranslate = _displayBody;
    if (textToTranslate.isEmpty) {
      if (mounted) {
        setState(() {
          _translateError = 'No email content to translate';
          _isTranslating = false;
        });
      }
      return;
    }

    // Clean HTML entities before sending to Gemini
    final cleanBody = textToTranslate
        .replaceAll('&#39;', "'")
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&#x27;', "'")
        .replaceAll('&nbsp;', ' ');

    final translated = await _gemini.translateEmail(
      body: cleanBody,
      targetLanguage: language,
    );
    if (mounted) {
      setState(() {
        if (translated != null && translated.isNotEmpty) {
          _translatedBody = translated;
        } else {
          _translateError = 'Translation failed — try again';
        }
        _isTranslating = false;
      });
    }
  }

  Future<void> _loadSmartReplies() async {
    final replies = await _gemini.generateSmartReplies(
      from: widget.email.from.displayName,
      subject: widget.email.subject,
      body: _displayBody,
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

                      // AI Summary — auto-generated, matches reference
                      if (_isLoadingSummary)
                        Padding(
                          padding: const EdgeInsets.only(top: 16),
                          child: Row(
                            children: [
                              const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: VoidColors.accentSkyBlue,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'GENERATING SUMMARY...',
                                style: Typo.mono.copyWith(
                                  color: VoidColors.accentSkyBlue,
                                  letterSpacing: 1,
                                ),
                              ),
                            ],
                          ),
                        )
                      else if (widget.email.aiSummary != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 16),
                          child: AISummaryCard(
                            summary: widget.email.aiSummary,
                          ),
                        ),
                      const SizedBox(height: 12),

                      // AI Translate status
                      if (_isTranslating)
                        Padding(
                          padding: const EdgeInsets.only(top: 10),
                          child: Row(
                            children: [
                              const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: VoidColors.accentPink,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'TRANSLATING...',
                                style: Typo.mono.copyWith(
                                  color: VoidColors.accentPink,
                                  letterSpacing: 1,
                                ),
                              ),
                            ],
                          ),
                        ),

                      if (_translateError != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.warning_amber_rounded,
                                size: 13,
                                color: VoidColors.accentYellow,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                _translateError!,
                                style: Typo.mono.copyWith(
                                  color: VoidColors.accentYellow,
                                ),
                              ),
                            ],
                          ),
                        ),

                      // Action row: Translate, Listen
                      _buildActionRow(),
                      const SizedBox(height: 20),

                      // Email body loading indicator
                      if (_isLoadingBody)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Row(
                            children: [
                              const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: VoidColors.textTertiary,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'LOADING FULL EMAIL...',
                                style: Typo.mono.copyWith(
                                  color: VoidColors.textTertiary,
                                  letterSpacing: 1,
                                ),
                              ),
                            ],
                          ),
                        ),

                      // Email body
                      Text(
                        _translatedBody ?? _displayBody,
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
              widget.email.isStarred ? Icons.star : Icons.star_outline,
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
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Row(
        children: [
          // Translate menu
          IgnorePointer(
            ignoring: _isTranslating || _isLoadingBody,
            child: Opacity(
              opacity: (_isTranslating || _isLoadingBody) ? 0.5 : 1.0,
              child: PopupMenuButton<String>(
                offset: const Offset(0, 40),
                color: VoidColors.bgCard,
                itemBuilder: (_) => [
                  'Spanish',
                  'French',
                  'German',
                  'Japanese',
                  'Hindi',
                  'Chinese (Simplified)',
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
                      const Icon(
                        Icons.language,
                        size: 14,
                        color: VoidColors.accentPink,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'AI TRANSLATE',
                        style: Typo.mono.copyWith(
                          fontSize: 13,
                          color: VoidColors.accentPink,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          const SizedBox(width: 10),

          if (_translatedBody != null)
            GestureDetector(
              onTap: () => setState(() {
                _translatedBody = null;
                _translateError = null;
              }),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: VoidColors.bgCard,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.undo,
                      size: 12,
                      color: VoidColors.textSecondary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'ORIGINAL',
                      style: Typo.mono.copyWith(
                        fontSize: 13,
                        color: VoidColors.textSecondary,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),

          const Spacer(),

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
                          _isPlaying ? Icons.pause : Icons.play_circle_filled,
                          size: 15,
                          color: VoidColors.accentGreen,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          _isPlaying ? 'PAUSE' : 'LISTEN TO EMAIL',
                          style: Typo.mono.copyWith(
                            fontSize: 13,
                            color: VoidColors.accentGreen,
                            letterSpacing: 0.5,
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
      text: _displayBody,
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

  /// Download an attachment and open it with native preview
  Future<void> _downloadAndPreview(Attachment attachment) async {
    if (_downloadingAttachments.contains(attachment.id)) return;

    // If already downloaded, just open it
    if (_downloadedPaths.containsKey(attachment.id)) {
      await OpenFilex.open(_downloadedPaths[attachment.id]!);
      return;
    }

    if (!attachment.isDownloadable) return;

    setState(() => _downloadingAttachments.add(attachment.id));

    try {
      final gmail = context.read<GmailService>();
      final bytes = await gmail.downloadAttachment(
        messageId: attachment.messageId!,
        attachmentId: attachment.attachmentId!,
      );

      if (bytes != null && mounted) {
        // Save to temp directory
        final tempDir = await getTemporaryDirectory();
        final file = File('${tempDir.path}/${attachment.name}');
        await file.writeAsBytes(bytes);

        _downloadedPaths[attachment.id] = file.path;
        setState(() => _downloadingAttachments.remove(attachment.id));

        // Open with native viewer
        await OpenFilex.open(file.path);
      } else if (mounted) {
        setState(() => _downloadingAttachments.remove(attachment.id));
      }
    } catch (e) {
      debugPrint('Error downloading attachment: $e');
      if (mounted) {
        setState(() => _downloadingAttachments.remove(attachment.id));
      }
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
              final isDownloading = _downloadingAttachments.contains(attachment.id);
              final isDownloaded = _downloadedPaths.containsKey(attachment.id);
              return GestureDetector(
                onTap: () => _downloadAndPreview(attachment),
                child: Container(
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
                      const SizedBox(width: 6),
                      if (isDownloading)
                        const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: VoidColors.accentSkyBlue,
                          ),
                        )
                      else
                        Icon(
                          isDownloaded ? Icons.check_circle : Icons.download,
                          size: 14,
                          color: isDownloaded
                              ? VoidColors.accentGreen
                              : VoidColors.textTertiary,
                        ),
                    ],
                  ),
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
            Icons.shortcut,
            'Reply',
            VoidColors.accentSkyBlue,
            () => _openCompose(null, mode: ComposeMode.reply),
            flipHorizontal: true,
          ),
          _buildActionButton(
            Icons.reply_all_outlined,
            'Reply All',
            VoidColors.accentGreen,
            () => _openCompose(null, mode: ComposeMode.replyAll),
          ),
          _buildActionButton(
            Icons.shortcut,
            'Forward',
            VoidColors.accentPink,
            () => _openCompose(null, mode: ComposeMode.forward),
          ),
          _buildActionButton(
            widget.email.isStarred ? Icons.star : Icons.star_outline,
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
      IconData icon, String label, Color color, VoidCallback onTap,
      {bool flipHorizontal = false}) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Transform(
            alignment: Alignment.center,
            transform: flipHorizontal
                ? (Matrix4.identity()..setEntry(0, 0, -1.0))
                : Matrix4.identity(),
            child: Icon(icon, size: 24, color: color),
          ),
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
