import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../design_system/colors.dart';
import '../../design_system/typography.dart';
import '../../design_system/components.dart';
import '../../models/account.dart';
import '../../services/gmail_service.dart';
import '../../services/gemini_service.dart';
import '../../services/calendar_service.dart';

/// Helix-o1 AI Copilot Dashboard with real-data digest, dynamic alerts,
/// inbox context in chat, inbox zero progress bar, real calendar count
class HelixO1View extends StatefulWidget {
  const HelixO1View({super.key});

  @override
  State<HelixO1View> createState() => _HelixO1ViewState();
}

class _HelixO1ViewState extends State<HelixO1View>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  final _gemini = GeminiService();
  final _chatController = TextEditingController();
  final _scrollController = ScrollController();

  String? _digestText;
  bool _isLoadingDigest = false;
  final List<_ChatMessage> _messages = [];
  bool _isChatLoading = false;

  // Dynamic alerts (generated from real data)
  List<AIAlert> _alerts = [];

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..forward();
    _loadDigest();
    _generateDynamicAlerts();
  }

  @override
  void dispose() {
    _controller.dispose();
    _chatController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  /// Load real-data digest with actual email subjects and snippets
  Future<void> _loadDigest() async {
    final gmail = context.read<GmailService>();
    setState(() => _isLoadingDigest = true);

    // Build real email data for the digest
    final emailData = gmail.emails.take(10).map((e) => {
          'from': e.from.displayName,
          'subject': e.subject,
          'snippet': e.snippet,
          'isRead': e.isRead,
        }).toList();

    final digest = await _gemini.generateDigest(
      emailCount: gmail.emails.length,
      unreadCount: gmail.unreadCount,
      emails: emailData,
    );

    if (mounted) {
      setState(() {
        _digestText = digest;
        _isLoadingDigest = false;
      });
    }
  }

  /// Generate dynamic smart alerts from actual email/calendar data
  void _generateDynamicAlerts() {
    final gmail = context.read<GmailService>();
    final calendar = context.read<CalendarService>();
    final alerts = <AIAlert>[];

    // Unread emails older than 1 day → "Awaiting Reply"
    final now = DateTime.now();
    for (final email in gmail.emails) {
      if (!email.isRead &&
          now.difference(email.date).inHours > 24) {
        alerts.add(AIAlert(
          id: 'await_${email.id}',
          type: AlertType.awaitingReply,
          title: email.from.displayName,
          subtitle: '${email.subject} - awaiting your response',
          emailId: email.id,
        ));
        if (alerts.where((a) => a.type == AlertType.awaitingReply).length >= 2) break;
      }
    }

    // Upcoming meetings today
    final todayEvents = calendar.events.where((e) {
      return e.startDate.year == now.year &&
          e.startDate.month == now.month &&
          e.startDate.day == now.day &&
          e.startDate.isAfter(now);
    }).toList();

    for (final event in todayEvents.take(2)) {
      final diff = event.startDate.difference(now);
      final timeStr = diff.inHours > 0
          ? 'In ${diff.inHours} hour${diff.inHours > 1 ? 's' : ''}'
          : 'In ${diff.inMinutes} min';
      alerts.add(AIAlert(
        id: 'meeting_${event.id}',
        type: AlertType.upcomingMeeting,
        title: event.title,
        subtitle: '$timeStr${event.location != null ? ' - ${event.location}' : ''}',
        eventId: event.id,
      ));
    }

    // New senders (emails from addresses seen only once)
    final senderCounts = <String, int>{};
    for (final email in gmail.emails) {
      senderCounts[email.from.email] =
          (senderCounts[email.from.email] ?? 0) + 1;
    }
    for (final email in gmail.emails) {
      if (senderCounts[email.from.email] == 1 && !email.isRead) {
        alerts.add(AIAlert(
          id: 'new_${email.id}',
          type: AlertType.newSender,
          title: email.from.displayName,
          subtitle: 'First email from this sender',
          emailId: email.id,
        ));
        if (alerts.where((a) => a.type == AlertType.newSender).isNotEmpty) break;
      }
    }

    setState(() => _alerts = alerts);
  }

  /// Build inbox context string for chat
  String _buildInboxContext() {
    final gmail = context.read<GmailService>();
    final recentEmails = gmail.emails.take(5);
    final buffer = StringBuffer();
    buffer.writeln('Inbox context (${gmail.emails.length} total, ${gmail.unreadCount} unread):');
    for (final email in recentEmails) {
      buffer.writeln(
          '- From: ${email.from.displayName}, Subject: ${email.subject}, '
          'Read: ${email.isRead}, Starred: ${email.isStarred}');
    }
    return buffer.toString();
  }

  Future<void> _sendMessage() async {
    final text = _chatController.text.trim();
    if (text.isEmpty) return;

    setState(() {
      _messages.add(_ChatMessage(text: text, isUser: true));
      _isChatLoading = true;
    });
    _chatController.clear();
    _scrollToBottom();

    // Include inbox context in chat
    final reply = await _gemini.chat(
      message: text,
      context: _buildInboxContext(),
    );

    if (mounted) {
      setState(() {
        _messages.add(_ChatMessage(
          text: reply ?? 'I couldn\'t process that request.',
          isUser: false,
        ));
        _isChatLoading = false;
      });
      _scrollToBottom();
    }
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final gmail = context.watch<GmailService>();
    final calendar = context.watch<CalendarService>();

    // Real calendar event count for today
    final now = DateTime.now();
    final todayEventCount = calendar.events.where((e) =>
        e.startDate.year == now.year &&
        e.startDate.month == now.month &&
        e.startDate.day == now.day).length;

    return Scaffold(
      backgroundColor: VoidColors.bgDeep,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            _buildHeader(),

            // Content
            Expanded(
              child: FadeTransition(
                opacity: _controller,
                child: ListView(
                  controller: _scrollController,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20),
                  children: [
                    const SizedBox(height: 8),

                    // Branding
                    _buildBranding(),
                    const SizedBox(height: 24),

                    // Inbox Zero Progress Bar
                    _buildInboxZeroProgress(gmail),
                    const SizedBox(height: 16),

                    // Inbox Digest
                    _buildDigestCard(),
                    const SizedBox(height: 16),

                    // Quick Stats
                    _buildQuickStats(gmail, todayEventCount),
                    const SizedBox(height: 24),

                    // Smart Alerts
                    if (_alerts.isNotEmpty) ...[
                      _buildAlertsSection(),
                      const SizedBox(height: 24),
                    ],

                    // Chat messages
                    ..._messages.map((msg) => _buildChatBubble(msg)),

                    if (_isChatLoading)
                      _buildTypingIndicator(),

                    const SizedBox(height: 80),
                  ],
                ),
              ),
            ),

            // Chat input
            _buildChatInput(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(
              Icons.arrow_back,
              color: VoidColors.textPrimary,
            ),
          ),
          const Spacer(),
          Text('HELIX-O1', style: Typo.metaLabel),
          const Spacer(),
          const SizedBox(width: 48),
        ],
      ),
    );
  }

  Widget _buildBranding() {
    return Row(
      children: [
        // Pulsing sparkle
        TweenAnimationBuilder<double>(
          tween: Tween(begin: 0.8, end: 1.2),
          duration: const Duration(seconds: 2),
          builder: (context, scale, child) {
            return Transform.scale(
              scale: scale,
              child: const Icon(
                Icons.auto_awesome,
                size: 32,
                color: VoidColors.accentSkyBlue,
              ),
            );
          },
          onEnd: () {}, // Will rebuild with AnimatedBuilder
        ),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Helix-o1',
              style: Typo.title3.copyWith(
                color: VoidColors.accentSkyBlue,
              ),
            ),
            Text(
              'Your AI copilot',
              style: Typo.subhead.copyWith(fontSize: 13),
            ),
          ],
        ),
      ],
    );
  }

  /// Inbox Zero Progress Bar
  Widget _buildInboxZeroProgress(GmailService gmail) {
    final total = gmail.emails.length;
    final read = total - gmail.unreadCount;
    final progress = total > 0 ? read / total : 1.0;
    final percentage = (progress * 100).toInt();

    return VoidCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.inbox,
                size: 16,
                color: VoidColors.accentGreen,
              ),
              const SizedBox(width: 8),
              Text(
                'INBOX ZERO',
                style: Typo.metaLabel.copyWith(
                  color: VoidColors.accentGreen,
                ),
              ),
              const Spacer(),
              Text(
                '$percentage%',
                style: Typo.mono.copyWith(
                  color: VoidColors.accentGreen,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: VoidColors.bgCardHover,
              valueColor: AlwaysStoppedAnimation<Color>(
                progress >= 1.0
                    ? VoidColors.accentGreen
                    : VoidColors.accentSkyBlue,
              ),
              minHeight: 6,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '$read of $total emails read',
            style: Typo.monoSmall,
          ),
        ],
      ),
    );
  }

  Widget _buildDigestCard() {
    return VoidCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.summarize,
                size: 16,
                color: VoidColors.accentSkyBlue,
              ),
              const SizedBox(width: 8),
              Text(
                'INBOX DIGEST',
                style: Typo.metaLabel.copyWith(
                  color: VoidColors.accentSkyBlue,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_isLoadingDigest)
            Column(
              children: const [
                ShimmerLine(width: double.infinity, height: 14),
                SizedBox(height: 8),
                ShimmerLine(width: 250, height: 14),
                SizedBox(height: 8),
                ShimmerLine(width: 180, height: 14),
              ],
            )
          else
            Text(
              _digestText ?? 'Loading digest...',
              style: Typo.subhead.copyWith(height: 1.5),
            ),
        ],
      ),
    );
  }

  Widget _buildQuickStats(GmailService gmail, int todayEventCount) {
    return Row(
      children: [
        _buildStatTile(
          '${gmail.unreadCount}',
          'Unread',
          Icons.mark_email_unread,
          VoidColors.accentGreen,
        ),
        const SizedBox(width: 8),
        _buildStatTile(
          '${gmail.starredCount}',
          'Starred',
          Icons.star,
          VoidColors.accentYellow,
        ),
        const SizedBox(width: 8),
        _buildStatTile(
          '$todayEventCount',
          'Events',
          Icons.event,
          VoidColors.accentSkyBlue,
        ),
        const SizedBox(width: 8),
        _buildStatTile(
          '${gmail.attachmentCount}',
          'Files',
          Icons.attach_file,
          VoidColors.accentPink,
        ),
      ],
    );
  }

  Widget _buildStatTile(
      String value, String label, IconData icon, Color color) {
    return Expanded(
      child: VoidCard(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
        child: Column(
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(height: 8),
            Text(
              value,
              style: Typo.title3.copyWith(fontSize: 22, color: color),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: Typo.caption.copyWith(fontSize: 11),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAlertsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('SMART ALERTS', style: Typo.metaLabel),
        const SizedBox(height: 12),
        ...List.generate(_alerts.length, (index) {
          final alert = _alerts[index];
          return TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.0, end: 1.0),
            duration: Duration(milliseconds: 400 + (index * 100)),
            curve: Curves.easeOutCubic,
            builder: (context, value, child) {
              return Opacity(
                opacity: value,
                child: Transform.translate(
                  offset: Offset(0, 20 * (1 - value)),
                  child: child,
                ),
              );
            },
            child: Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _buildAlertCard(alert),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildAlertCard(AIAlert alert) {
    return Dismissible(
      key: Key(alert.id),
      direction: DismissDirection.endToStart,
      onDismissed: (_) {
        setState(() => _alerts.removeWhere((a) => a.id == alert.id));
      },
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        color: VoidColors.accentPink.withValues(alpha: 0.2),
        child: const Icon(
          Icons.close,
          color: VoidColors.accentPink,
        ),
      ),
      child: VoidCard(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: alert.color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(alert.icon, size: 18, color: alert.color),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    alert.title,
                    style: Typo.headline.copyWith(fontSize: 14),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    alert.subtitle,
                    style: Typo.subhead.copyWith(fontSize: 12),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: alert.color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                alert.type.label,
                style: Typo.caption.copyWith(
                  fontSize: 13,
                  color: alert.color,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChatBubble(_ChatMessage message) {
    return Align(
      alignment:
          message.isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        decoration: BoxDecoration(
          color: message.isUser
              ? VoidColors.textPrimary
              : VoidColors.bgCard,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(message.isUser ? 16 : 4),
            bottomRight: Radius.circular(message.isUser ? 4 : 16),
          ),
        ),
        child: Text(
          message.text,
          style: Typo.body.copyWith(
            fontSize: 15,
            color: message.isUser
                ? VoidColors.textInverse
                : VoidColors.textPrimary,
          ),
        ),
      ),
    );
  }

  Widget _buildTypingIndicator() {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: VoidColors.bgCard,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (i) {
            return TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.3, end: 1.0),
              duration: Duration(milliseconds: 600 + (i * 200)),
              builder: (context, value, child) {
                return Container(
                  width: 8,
                  height: 8,
                  margin: const EdgeInsets.symmetric(horizontal: 2),
                  decoration: BoxDecoration(
                    color: VoidColors.accentSkyBlue
                        .withValues(alpha: value),
                    shape: BoxShape.circle,
                  ),
                );
              },
            );
          }),
        ),
      ),
    );
  }

  Widget _buildChatInput() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      color: VoidColors.bgDeep,
      child: Row(
        children: [
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: VoidColors.bgCard,
                borderRadius: BorderRadius.circular(24),
                border:
                    Border.all(color: VoidColors.border, width: 0.5),
              ),
              child: TextField(
                controller: _chatController,
                style: Typo.body.copyWith(fontSize: 15),
                decoration: InputDecoration(
                  hintText: 'Ask Helix anything...',
                  hintStyle: Typo.body.copyWith(
                    fontSize: 15,
                    color: VoidColors.textTertiary,
                  ),
                  border: InputBorder.none,
                  contentPadding:
                      const EdgeInsets.symmetric(vertical: 12),
                ),
                onSubmitted: (_) => _sendMessage(),
              ),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: _sendMessage,
            child: Container(
              width: 44,
              height: 44,
              decoration: const BoxDecoration(
                color: VoidColors.accentSkyBlue,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.arrow_upward,
                color: VoidColors.textInverse,
                size: 20,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ChatMessage {
  final String text;
  final bool isUser;

  _ChatMessage({required this.text, required this.isUser});
}
