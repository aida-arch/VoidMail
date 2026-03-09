import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../design_system/colors.dart';
import '../../design_system/typography.dart';
import '../../design_system/components.dart';
import '../../models/email.dart';
import '../../services/gmail_service.dart';
import '../../services/auth_service.dart';
import 'email_row_view.dart';
import 'email_detail_view.dart';

/// Main Inbox Interface with category filters, swipe actions, and date grouping
class InboxView extends StatefulWidget {
  final VoidCallback onHelixTap;

  const InboxView({super.key, required this.onHelixTap});

  @override
  State<InboxView> createState() => _InboxViewState();
}

class _InboxViewState extends State<InboxView> {
  String _selectedCategory = 'All';
  String? _selectedAccount;
  bool _showUnreadOnly = false;

  final _categories = ['All', 'Priority', 'Updates', 'Newsletters'];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final gmail = context.read<GmailService>();
      if (gmail.emails.isEmpty) {
        gmail.loadMockEmails();
      }
    });
  }

  List<Email> _getFilteredEmails(GmailService gmail) {
    var emails = gmail.emails;

    // Filter by category
    if (_selectedCategory != 'All') {
      final category = EmailCategory.values.firstWhere(
        (c) => c.label == _selectedCategory,
        orElse: () => EmailCategory.primary,
      );
      emails = emails.where((e) => e.category == category).toList();
    }

    // Filter by account
    if (_selectedAccount != null) {
      emails =
          emails.where((e) => e.accountEmail == _selectedAccount).toList();
    }

    // Filter by unread
    if (_showUnreadOnly) {
      emails = emails.where((e) => !e.isRead).toList();
    }

    return emails;
  }

  Map<String, List<Email>> _groupByDate(List<Email> emails) {
    final Map<String, List<Email>> grouped = {};
    for (final email in emails) {
      final key = email.dateGroupKey;
      grouped.putIfAbsent(key, () => []).add(email);
    }
    return grouped;
  }

  @override
  Widget build(BuildContext context) {
    final gmail = context.watch<GmailService>();
    final auth = context.watch<AuthService>();
    final filtered = _getFilteredEmails(gmail);
    final grouped = _groupByDate(filtered);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        _buildHeader(gmail, auth),

        // Category chips
        FilterChipBar(
          filters: _categories,
          selected: _selectedCategory,
          onSelected: (cat) => setState(() => _selectedCategory = cat),
        ),

        const SizedBox(height: 8),

        // Email list
        Expanded(
          child: gmail.isLoading
              ? _buildSkeletonList()
              : filtered.isEmpty
                  ? const EmptyStateView(
                      icon: Icons.inbox,
                      title: 'All clear',
                      subtitle: 'No emails match your filters',
                    )
                  : RefreshIndicator(
                      color: VoidColors.accentGreen,
                      backgroundColor: VoidColors.bgSurface,
                      onRefresh: () => gmail.fetchEmails(),
                      child: _buildEmailList(grouped, gmail),
                    ),
        ),
      ],
    );
  }

  Widget _buildHeader(GmailService gmail, AuthService auth) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Meta row
          Row(
            children: [
              Text(
                'VOIDMAIL',
                style: Typo.metaLabel,
              ),
              const Spacer(),
              // Unread count
              Text(
                '${gmail.unreadCount}',
                style: Typo.mono.copyWith(
                  color: gmail.unreadCount > 0
                      ? VoidColors.accentYellow
                      : VoidColors.textTertiary,
                  letterSpacing: 1,
                ),
              ),
              const SizedBox(width: 12),
              // Sync circle button
              GestureDetector(
                onTap: () => gmail.fetchEmails(),
                child: Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: VoidColors.accentGreen.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: gmail.isSyncing
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: VoidColors.accentGreen,
                            ),
                          )
                        : const Icon(
                            Icons.refresh,
                            size: 16,
                            color: VoidColors.accentGreen,
                          ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // Helix AI circle button
              GestureDetector(
                onTap: widget.onHelixTap,
                child: Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: VoidColors.accentSkyBlue.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.auto_awesome,
                      size: 16,
                      color: VoidColors.accentSkyBlue,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          // Title row with inline account dropdown + read filter
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                'INBOX',
                style: Typo.inboxTitle,
              ),
              const SizedBox(width: 12),
              if (auth.accounts.length > 1)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: TagChip(
                    label: _selectedAccount ?? 'All',
                    onTap: () {
                      _showAccountPicker(auth);
                    },
                  ),
                ),
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: TagChip(
                  label: _showUnreadOnly ? 'Unread' : 'All',
                  isActive: _showUnreadOnly,
                  onTap: () =>
                      setState(() => _showUnreadOnly = !_showUnreadOnly),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showAccountPicker(AuthService auth) {
    showModalBottomSheet(
      context: context,
      backgroundColor: VoidColors.bgCard,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: Text('All Accounts', style: Typo.body),
              onTap: () {
                setState(() => _selectedAccount = null);
                Navigator.pop(context);
              },
            ),
            ...auth.accounts.map((account) => ListTile(
                  title: Text(account.label, style: Typo.body),
                  subtitle: Text(account.email, style: Typo.monoSmall),
                  onTap: () {
                    setState(() => _selectedAccount = account.email);
                    Navigator.pop(context);
                  },
                )),
          ],
        ),
      ),
    );
  }

  Widget _buildSkeletonList() {
    return ListView.builder(
      itemCount: 6,
      itemBuilder: (context, index) => const ShimmerEmailRow(),
    );
  }

  Widget _buildEmailList(
      Map<String, List<Email>> grouped, GmailService gmail) {
    final groups = grouped.entries.toList();

    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 100),
      itemCount: groups.fold<int>(0, (sum, g) => sum + g.value.length + 1),
      itemBuilder: (context, index) {
        int current = 0;
        for (final group in groups) {
          // Date divider
          if (index == current) {
            return DateDivider(label: group.key);
          }
          current++;

          // Emails in group
          for (int i = 0; i < group.value.length; i++) {
            if (index == current) {
              final email = group.value[i];
              return Column(
                children: [
                  EmailRowView(
                    email: email,
                    index: i,
                    onTap: () => _navigateToDetail(email),
                    onSwipeLeft: () => gmail.deleteEmail(email.id),
                    onSwipeRight: () => gmail.toggleRead(email.id),
                  ),
                  if (i < group.value.length - 1)
                    const Padding(
                      padding: EdgeInsets.only(left: 72),
                      child: Divider(
                        height: 0.5,
                        color: VoidColors.border,
                      ),
                    ),
                ],
              );
            }
            current++;
          }
        }
        return const SizedBox.shrink();
      },
    );
  }

  void _navigateToDetail(Email email) {
    // Mark as read
    if (!email.isRead) {
      context.read<GmailService>().toggleRead(email.id);
    }

    Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            EmailDetailView(email: email),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(
            opacity: animation,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0.05, 0),
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
}
