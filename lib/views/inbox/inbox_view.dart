import 'dart:ui';
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
  bool _showReadOnly = false;
  final GlobalKey _accountPillKey = GlobalKey();
  final GlobalKey _filterPillKey = GlobalKey();

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

    // Filter by read status
    if (_showUnreadOnly) {
      emails = emails.where((e) => !e.isRead).toList();
    } else if (_showReadOnly) {
      emails = emails.where((e) => e.isRead).toList();
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
    final unread = gmail.unreadCount;
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
              // Unread count with label
              Text(
                '$unread UNREAD',
                style: Typo.mono.copyWith(
                  color: unread > 0
                      ? VoidColors.accentYellow
                      : VoidColors.textTertiary,
                  letterSpacing: 1,
                ),
              ),
              const SizedBox(width: 8),
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
          // Title row with inline filter pills
          Transform.translate(
            offset: const Offset(0, -6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  'INBOX',
                  style: Typo.inboxTitle,
                ),
                const Spacer(),
                // Account dropdown pill
                Builder(
                  key: _accountPillKey,
                  builder: (ctx) => _buildDropdownPill(
                    label: _selectedAccount != null
                        ? auth.accounts
                            .firstWhere(
                              (a) => a.email == _selectedAccount,
                              orElse: () => auth.accounts.first,
                            )
                            .label
                        : 'All',
                    onTap: () => _showAccountPicker(auth),
                    maxWidth: 80,
                  ),
                ),
                const SizedBox(width: 6),
                // Read/Unread filter pill
                _buildFilterPill(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDropdownPill({
    required String label,
    required VoidCallback onTap,
    double? maxWidth,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: VoidColors.bgCard,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: VoidColors.border,
            width: 0.5,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maxWidth ?? 100),
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: VoidColors.textSecondary,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 4),
            const Icon(
              Icons.keyboard_arrow_down,
              size: 14,
              color: VoidColors.textTertiary,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterPill() {
    final isFiltered = _showUnreadOnly || _showReadOnly;
    final label = _showUnreadOnly
        ? 'Unread'
        : _showReadOnly
            ? 'Read'
            : 'Filter';
    return Builder(
      key: _filterPillKey,
      builder: (ctx) => GestureDetector(
        onTap: () => _showFilterPicker(),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: isFiltered
                ? VoidColors.accentSkyBlue.withValues(alpha: 0.15)
                : VoidColors.bgCard,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isFiltered ? VoidColors.accentSkyBlue.withValues(alpha: 0.3) : VoidColors.border,
              width: 0.5,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                _showUnreadOnly
                    ? Icons.mark_email_unread_outlined
                    : _showReadOnly
                        ? Icons.drafts_outlined
                        : Icons.mail_outline,
                size: 14,
                color: isFiltered
                    ? VoidColors.accentSkyBlue
                    : VoidColors.textTertiary,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: isFiltered
                      ? VoidColors.accentSkyBlue
                      : VoidColors.textSecondary,
                ),
              ),
              const SizedBox(width: 4),
              Icon(
                Icons.keyboard_arrow_down,
                size: 16,
                color: isFiltered
                    ? VoidColors.accentSkyBlue
                    : VoidColors.textTertiary,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showFilterPicker() {
    final renderBox =
        _filterPillKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null) return;

    final position = renderBox.localToGlobal(Offset.zero);
    final size = renderBox.size;
    final isFiltered = _showUnreadOnly || _showReadOnly;

    Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false,
        barrierDismissible: true,
        barrierColor: Colors.black38,
        transitionDuration: const Duration(milliseconds: 260),
        reverseTransitionDuration: const Duration(milliseconds: 200),
        pageBuilder: (context, animation, secondaryAnimation) {
          final curvedAnimation = CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutCubic,
          );

          return FadeTransition(
            opacity: curvedAnimation,
            child: Stack(
              children: [
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  behavior: HitTestBehavior.opaque,
                  child: const SizedBox.expand(),
                ),
                Positioned(
                  right: 20,
                  top: position.dy + size.height + 8,
                  child: ScaleTransition(
                    scale: Tween<double>(begin: 0.85, end: 1.0)
                        .animate(curvedAnimation),
                    alignment: Alignment.topRight,
                    child: Material(
                      color: Colors.transparent,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 50, sigmaY: 50),
                          child: Container(
                            width: 240,
                            decoration: BoxDecoration(
                              color: const Color(0xFF1C1C1E)
                                  .withValues(alpha: 0.78),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.1),
                                width: 0.5,
                              ),
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                _buildFilterOption(
                                  context: context,
                                  icon: Icons.mark_email_unread_outlined,
                                  label: 'Unread',
                                  isSelected: _showUnreadOnly,
                                  onTap: () {
                                    setState(() {
                                      _showUnreadOnly = true;
                                      _showReadOnly = false;
                                    });
                                    Navigator.pop(context);
                                  },
                                ),
                                _buildFilterOption(
                                  context: context,
                                  icon: Icons.drafts_outlined,
                                  label: 'Read',
                                  isSelected: _showReadOnly,
                                  onTap: () {
                                    setState(() {
                                      _showReadOnly = true;
                                      _showUnreadOnly = false;
                                    });
                                    Navigator.pop(context);
                                  },
                                ),
                                if (isFiltered) ...[
                                  Divider(
                                    height: 0.5,
                                    indent: 20,
                                    endIndent: 20,
                                    color:
                                        Colors.white.withValues(alpha: 0.15),
                                  ),
                                  _buildFilterOption(
                                    context: context,
                                    icon: Icons.cancel_outlined,
                                    label: 'Clear Filter',
                                    isSelected: false,
                                    isDestructive: true,
                                    onTap: () {
                                      setState(() {
                                        _showUnreadOnly = false;
                                        _showReadOnly = false;
                                      });
                                      Navigator.pop(context);
                                    },
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildFilterOption({
    required BuildContext context,
    required IconData icon,
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
    bool isDestructive = false,
  }) {
    final color = isDestructive
        ? const Color(0xFFFF6B6B)
        : isSelected
            ? VoidColors.textPrimary
            : VoidColors.textSecondary;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Row(
          children: [
            Icon(icon, size: 26, color: color),
            const SizedBox(width: 16),
            Text(
              label,
              style: Typo.body.copyWith(color: color, fontSize: 18),
            ),
          ],
        ),
      ),
    );
  }

  void _showAccountPicker(AuthService auth) {
    final renderBox =
        _accountPillKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null) return;

    final position = renderBox.localToGlobal(Offset.zero);
    final size = renderBox.size;

    Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false,
        barrierDismissible: true,
        barrierColor: Colors.black38,
        transitionDuration: const Duration(milliseconds: 260),
        reverseTransitionDuration: const Duration(milliseconds: 200),
        pageBuilder: (context, animation, secondaryAnimation) {
          final curvedAnimation = CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutCubic,
          );

          return FadeTransition(
            opacity: curvedAnimation,
            child: Stack(
              children: [
                // Dismiss on tap outside
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  behavior: HitTestBehavior.opaque,
                  child: const SizedBox.expand(),
                ),
                Positioned(
                  left: 20,
                  top: position.dy + size.height + 8,
                  child: ScaleTransition(
                    scale: Tween<double>(begin: 0.85, end: 1.0)
                        .animate(curvedAnimation),
                    alignment: Alignment.topLeft,
                    child: Material(
                      color: Colors.transparent,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 50, sigmaY: 50),
                          child: Container(
                            width: 280,
                            decoration: BoxDecoration(
                              color: const Color(0xFF1C1C1E)
                                  .withValues(alpha: 0.78),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.1),
                                width: 0.5,
                              ),
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                _buildAccountOption(
                                  context: context,
                                  icon: Icons.all_inbox,
                                  label: 'All Inboxes',
                                  isSelected: _selectedAccount == null,
                                  onTap: () {
                                    setState(
                                        () => _selectedAccount = null);
                                    Navigator.pop(context);
                                  },
                                ),
                                Divider(
                                  height: 0.5,
                                  indent: 20,
                                  endIndent: 20,
                                  color: Colors.white
                                      .withValues(alpha: 0.15),
                                ),
                                ...auth.accounts.map((account) {
                                  final emailLabel = account.email
                                      .replaceAll('@gmail.com', '');
                                  return _buildAccountOption(
                                    context: context,
                                    icon: Icons.mail_outline,
                                    label: emailLabel,
                                    isSelected: _selectedAccount ==
                                        account.email,
                                    onTap: () {
                                      setState(() => _selectedAccount =
                                          account.email);
                                      Navigator.pop(context);
                                    },
                                  );
                                }),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildAccountOption({
    required BuildContext context,
    required IconData icon,
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Row(
          children: [
            Icon(
              icon,
              size: 26,
              color: isSelected
                  ? VoidColors.textPrimary
                  : VoidColors.textSecondary,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                label,
                style: Typo.body.copyWith(
                  color: isSelected
                      ? VoidColors.textPrimary
                      : VoidColors.textSecondary,
                  fontSize: 18,
                ),
              ),
            ),
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
