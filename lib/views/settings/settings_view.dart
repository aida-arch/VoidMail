import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../design_system/colors.dart';
import '../../design_system/typography.dart';
import '../../design_system/components.dart';
import '../../models/account.dart';
import '../../services/auth_service.dart';
import 'encryption_view.dart';
import 'about_view.dart';

/// Settings with accounts, preferences, signatures, privacy
class SettingsView extends StatefulWidget {
  const SettingsView({super.key});

  @override
  State<SettingsView> createState() => _SettingsViewState();
}

class _SettingsViewState extends State<SettingsView> {
  bool _smartNotifications = true;
  bool _aiSummaries = true;
  bool _blockTrackers = true;
  bool _readReceipts = false;
  String _appearance = 'dark';

  // Per-account signatures
  final Map<String, TextEditingController> _signatureControllers = {};

  @override
  void dispose() {
    for (final controller in _signatureControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();

    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: 120),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          ScreenHeader(
            metaLabel: 'VOIDMAIL',
            title: 'SETTINGS',
            trailing: [
              Text(
                'BUILD: 1.1',
                style: Typo.metaLabel,
              ),
            ],
          ),

          // Accounts section
          const SectionDivider(label: 'ACCOUNTS'),
          ...auth.accounts.map((account) => _buildAccountRow(account, auth)),
          _buildAddAccountButton(auth),

          // Preferences
          const SectionDivider(label: 'PREFERENCES'),
          ToggleRow(
            icon: Icons.notifications_active,
            label: 'Smart Notifications',
            value: _smartNotifications,
            onChanged: (v) => setState(() => _smartNotifications = v),
          ),
          ToggleRow(
            icon: Icons.auto_awesome,
            label: 'AI Summaries',
            value: _aiSummaries,
            onChanged: (v) => setState(() => _aiSummaries = v),
          ),

          // Email Signatures
          if (auth.accounts.isNotEmpty) ...[
            const SectionDivider(label: 'EMAIL SIGNATURES'),
            ...auth.accounts.map((account) => _buildSignatureEditor(account)),
          ],

          // Privacy & Security
          const SectionDivider(label: 'PRIVACY & SECURITY'),
          ToggleRow(
            icon: Icons.block,
            label: 'Block Trackers',
            value: _blockTrackers,
            onChanged: (v) => setState(() => _blockTrackers = v),
          ),
          ToggleRow(
            icon: Icons.visibility_off,
            label: 'Read Receipts',
            value: _readReceipts,
            onChanged: (v) => setState(() => _readReceipts = v),
          ),
          // Encryption settings link
          _buildNavigationRow(
            icon: Icons.enhanced_encryption,
            label: 'Encryption',
            subtitle: 'End-to-end encryption settings',
            color: VoidColors.accentGreen,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const EncryptionView()),
            ),
          ),

          // Appearance
          const SectionDivider(label: 'APPEARANCE'),
          _buildAppearancePicker(),

          // About
          const SectionDivider(label: 'ABOUT'),
          _buildAboutSection(),
          const SizedBox(height: 8),
          _buildNavigationRow(
            icon: Icons.info_outline,
            label: 'About VoidMail',
            subtitle: 'Version, features, and credits',
            color: VoidColors.accentSkyBlue,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const AboutView()),
            ),
          ),

          // Sign out
          if (auth.isSignedIn) ...[
            const SizedBox(height: 32),
            _buildSignOutButton(auth),
          ],
        ],
      ),
    );
  }

  Widget _buildAccountRow(UserAccount account, AuthService auth) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: VoidCard(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            // Color indicator
            Container(
              width: 8,
              height: 40,
              decoration: BoxDecoration(
                color: account.colorTag.color,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(width: 12),

            // Account info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    account.label,
                    style: Typo.headline.copyWith(fontSize: 15),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    account.email,
                    style: Typo.monoSmall,
                  ),
                ],
              ),
            ),

            // Color picker
            PopupMenuButton<AccountColor>(
              icon: Icon(
                Icons.circle,
                size: 16,
                color: account.colorTag.color,
              ),
              color: VoidColors.bgCard,
              onSelected: (color) {
                auth.setAccountColor(account.email, color);
              },
              itemBuilder: (_) => AccountColor.values
                  .map((c) => PopupMenuItem(
                        value: c,
                        child: Row(
                          children: [
                            Icon(Icons.circle, size: 14, color: c.color),
                            const SizedBox(width: 8),
                            Text(c.label, style: Typo.body),
                          ],
                        ),
                      ))
                  .toList(),
            ),

            // Edit label
            IconButton(
              icon: const Icon(
                Icons.edit,
                size: 16,
                color: VoidColors.textTertiary,
              ),
              onPressed: () => _showRenameDialog(account, auth),
            ),
          ],
        ),
      ),
    );
  }

  void _showRenameDialog(UserAccount account, AuthService auth) {
    final controller = TextEditingController(text: account.label);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: VoidColors.bgCard,
        title: Text('Rename Account', style: Typo.headline),
        content: TextField(
          controller: controller,
          style: Typo.body,
          decoration: InputDecoration(
            hintText: 'Account name',
            hintStyle: Typo.body.copyWith(color: VoidColors.textTertiary),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel',
                style: Typo.body.copyWith(color: VoidColors.textSecondary)),
          ),
          TextButton(
            onPressed: () {
              auth.setAccountLabel(account.email, controller.text);
              Navigator.pop(ctx);
            },
            child: Text('Save',
                style: Typo.body.copyWith(color: VoidColors.accentGreen)),
          ),
        ],
      ),
    );
  }

  Widget _buildAddAccountButton(AuthService auth) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: GestureDetector(
        onTap: () => auth.signInWithGoogle(),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: VoidColors.bgCard,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: VoidColors.border,
              width: 0.5,
              strokeAlign: BorderSide.strokeAlignInside,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.add,
                size: 18,
                color: VoidColors.accentGreen,
              ),
              const SizedBox(width: 8),
              Text(
                'Add Account',
                style: Typo.body.copyWith(
                  color: VoidColors.accentGreen,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSignatureEditor(UserAccount account) {
    _signatureControllers.putIfAbsent(
      account.email,
      () => TextEditingController(text: 'Best regards,\n${account.displayName}'),
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: ExpansionTile(
        tilePadding: EdgeInsets.zero,
        title: Text(
          account.label,
          style: Typo.body.copyWith(fontSize: 15),
        ),
        iconColor: VoidColors.textTertiary,
        collapsedIconColor: VoidColors.textTertiary,
        children: [
          TextField(
            controller: _signatureControllers[account.email],
            maxLines: 4,
            style: Typo.body.copyWith(fontSize: 14),
            decoration: InputDecoration(
              hintText: 'Enter email signature...',
              hintStyle: Typo.body.copyWith(
                fontSize: 14,
                color: VoidColors.textTertiary,
              ),
              filled: true,
              fillColor: VoidColors.bgCard,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildAppearancePicker() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Row(
        children: [
          const Icon(Icons.palette, size: 16, color: VoidColors.textSecondary),
          const SizedBox(width: 12),
          Text('Theme', style: Typo.body),
          const SizedBox(width: 12),
          Expanded(
            flex: 3,
            child: SegmentedButton<String>(
            showSelectedIcon: false,
            segments: const [
              ButtonSegment(value: 'dark', label: Text('Dark')),
              ButtonSegment(value: 'light', label: Text('Light')),
              ButtonSegment(value: 'system', label: Text('System')),
            ],
            selected: {_appearance},
            onSelectionChanged: (val) =>
                setState(() => _appearance = val.first),
            style: ButtonStyle(
              backgroundColor: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.selected)) {
                  return VoidColors.textPrimary;
                }
                return VoidColors.bgCard;
              }),
              foregroundColor: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.selected)) {
                  return VoidColors.textInverse;
                }
                return VoidColors.textSecondary;
              }),
              side: WidgetStateProperty.all(
                const BorderSide(color: VoidColors.border, width: 0.5),
              ),
            ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAboutSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: VoidCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'VOIDMAIL',
              style: Typo.title3.copyWith(fontSize: 20),
            ),
            const SizedBox(height: 4),
            Text(
              'by Neural Arc',
              style: Typo.subhead.copyWith(
                fontSize: 13,
                color: VoidColors.accentPink,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'A dark, minimal, AI-powered email experience. Built for focus.',
              style: Typo.subhead.copyWith(height: 1.5),
            ),
            const SizedBox(height: 12),
            Text(
              'Version 1.0.0',
              style: Typo.monoSmall,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNavigationRow({
    required IconData icon,
    required String label,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: VoidColors.bgCard,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 16, color: color),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label, style: Typo.body.copyWith(fontSize: 15)),
                    Text(
                      subtitle,
                      style: Typo.subhead.copyWith(
                        fontSize: 12,
                        color: VoidColors.textTertiary,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right,
                size: 16,
                color: VoidColors.textTertiary,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSignOutButton(AuthService auth) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: GestureDetector(
        onTap: () {
          showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              backgroundColor: VoidColors.bgCard,
              title: Text('Sign Out', style: Typo.headline),
              content: Text(
                'Are you sure you want to sign out of all accounts?',
                style: Typo.subhead,
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: Text('Cancel',
                      style: Typo.body
                          .copyWith(color: VoidColors.textSecondary)),
                ),
                TextButton(
                  onPressed: () {
                    auth.signOut();
                    Navigator.pop(ctx);
                  },
                  child: Text('Sign Out',
                      style:
                          Typo.body.copyWith(color: VoidColors.accentPink)),
                ),
              ],
            ),
          );
        },
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: VoidColors.accentPink.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: VoidColors.accentPink.withValues(alpha: 0.3),
              width: 0.5,
            ),
          ),
          child: Center(
            child: Text(
              'Sign Out',
              style: Typo.body.copyWith(
                color: VoidColors.accentPink,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
