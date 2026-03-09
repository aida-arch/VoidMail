import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../design_system/colors.dart';
import '../../design_system/typography.dart';
import '../../design_system/components.dart';
import '../../models/email.dart';
import '../../services/gmail_service.dart';
import '../../services/gemini_service.dart';
import '../inbox/email_detail_view.dart';

/// Search view with AI digest, tags, and full-text search
class SearchView extends StatefulWidget {
  const SearchView({super.key});

  @override
  State<SearchView> createState() => _SearchViewState();
}

class _SearchViewState extends State<SearchView> {
  final _searchController = TextEditingController();
  final _gemini = GeminiService();
  String? _digestText;
  bool _isLoadingDigest = false;
  List<Email> _searchResults = [];
  bool _isSearching = false;

  final _recentTags = [
    ('Attachments', Icons.attach_file),
    ('Starred', Icons.star),
    ('Unread', Icons.mark_email_unread),
    ('Sent', Icons.send),
    ('Drafts', Icons.drafts),
  ];

  @override
  void initState() {
    super.initState();
    _loadDigest();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    if (_searchController.text.isEmpty) {
      setState(() {
        _searchResults = [];
        _isSearching = false;
      });
      return;
    }

    setState(() => _isSearching = true);

    final gmail = context.read<GmailService>();
    final query = _searchController.text.toLowerCase();

    setState(() {
      _searchResults = gmail.emails.where((e) {
        return e.subject.toLowerCase().contains(query) ||
            e.from.displayName.toLowerCase().contains(query) ||
            e.from.email.toLowerCase().contains(query) ||
            e.snippet.toLowerCase().contains(query) ||
            e.body.toLowerCase().contains(query);
      }).toList();
      _isSearching = false;
    });
  }

  Future<void> _loadDigest() async {
    final gmail = context.read<GmailService>();
    setState(() => _isLoadingDigest = true);

    final digest = await _gemini.generateDigest(
      emailCount: gmail.emails.length,
      unreadCount: gmail.unreadCount,
    );

    if (mounted) {
      setState(() {
        _digestText = digest;
        _isLoadingDigest = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final gmail = context.watch<GmailService>();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        ScreenHeader(
          metaLabel: 'INDEX 01',
          title: 'SEARCH',
          trailing: [
            Text(
              '${gmail.emails.length} TOTAL',
              style: Typo.metaLabel,
            ),
          ],
        ),

        // Search field
        _buildSearchField(),

        const SizedBox(height: 16),

        Expanded(
          child: _searchController.text.isNotEmpty
              ? _buildSearchResults()
              : _buildDiscoveryContent(gmail),
        ),
      ],
    );
  }

  Widget _buildSearchField() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: VoidColors.bgCard,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.search,
              size: 20,
              color: VoidColors.textTertiary,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: TextField(
                controller: _searchController,
                style: Typo.body,
                decoration: InputDecoration(
                  hintText: 'Search emails...',
                  hintStyle: Typo.body.copyWith(
                    color: VoidColors.textTertiary,
                  ),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
            if (_searchController.text.isNotEmpty)
              GestureDetector(
                onTap: () => _searchController.clear(),
                child: const Icon(
                  Icons.close,
                  size: 18,
                  color: VoidColors.textTertiary,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildDiscoveryContent(GmailService gmail) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Recent tags
          Text(
            'RECENT',
            style: Typo.sectionLabel,
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _recentTags.map((tag) {
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: TagChip(
                    label: tag.$1,
                    icon: tag.$2,
                    onTap: () {
                      _searchController.text = tag.$1.toLowerCase();
                    },
                  ),
                );
              }).toList(),
            ),
          ),

          const SizedBox(height: 24),

          // AI Digest card
          VoidCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.auto_awesome,
                      size: 16,
                      color: VoidColors.accentSkyBlue,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'AI DIGEST',
                      style: Typo.metaLabel.copyWith(
                        color: VoidColors.accentSkyBlue,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Stats row
                Row(
                  children: [
                    _buildStatPill(
                      '${gmail.unreadCount}',
                      'Unread',
                      VoidColors.accentGreen,
                    ),
                    const SizedBox(width: 8),
                    _buildStatPill(
                      '${gmail.starredCount}',
                      'Starred',
                      VoidColors.accentYellow,
                    ),
                    const SizedBox(width: 8),
                    _buildStatPill(
                      '${gmail.attachmentCount}',
                      'Files',
                      VoidColors.accentSkyBlue,
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Digest text
                if (_isLoadingDigest)
                  Column(
                    children: const [
                      ShimmerLine(width: double.infinity, height: 14),
                      SizedBox(height: 8),
                      ShimmerLine(width: 200, height: 14),
                    ],
                  )
                else if (_digestText != null)
                  Text(
                    _digestText!,
                    style: Typo.subhead.copyWith(height: 1.5),
                  ),
              ],
            ),
          ),

          const SizedBox(height: 100),
        ],
      ),
    );
  }

  Widget _buildStatPill(String value, String label, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: Typo.caption.copyWith(
                color: color.withValues(alpha: 0.7),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchResults() {
    if (_isSearching) {
      return const Center(
        child: CircularProgressIndicator(color: VoidColors.accentGreen),
      );
    }

    if (_searchResults.isEmpty) {
      return const EmptyStateView(
        icon: Icons.search_off,
        title: 'No results',
        subtitle: 'Try a different search term',
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(0, 0, 0, 100),
      itemCount: _searchResults.length,
      separatorBuilder: (_, _) => const Padding(
        padding: EdgeInsets.only(left: 72),
        child: Divider(height: 0.5, color: VoidColors.border),
      ),
      itemBuilder: (context, index) {
        final email = _searchResults[index];
        return ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 20),
          leading: InitialsAvatar(
            name: email.from.displayName,
            size: 36,
          ),
          title: Text(
            email.from.displayName,
            style: Typo.headline.copyWith(fontSize: 15),
            maxLines: 1,
          ),
          subtitle: Text(
            email.subject,
            style: Typo.subhead.copyWith(fontSize: 13),
            maxLines: 1,
          ),
          trailing: Text(
            email.relativeDate,
            style: Typo.monoSmall,
          ),
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => EmailDetailView(email: email),
              ),
            );
          },
        );
      },
    );
  }
}
