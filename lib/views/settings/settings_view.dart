import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../design_system/colors.dart';
import '../../design_system/typography.dart';
import '../../design_system/components.dart';
import '../../models/account.dart';
import '../../services/auth_service.dart';
import '../../main.dart';
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
  bool _signatureEnabled = true;
  String? _editingSignatureAccount;

  final Map<String, TextEditingController> _signatureControllers = {};

  @override
  void dispose() {
    for (final c in _signatureControllers.values) {
      c.dispose();
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
          // Screen Header
          ScreenHeader(
            metaLabel: 'VOIDMAIL',
            title: 'SETTINGS',
            trailing: [
              Text('BUILD: 1.1', style: Typo.metaLabel),
            ],
          ),

          const SizedBox(height: 24),

          // ACCOUNTS
          _systemSection(
            title: 'ACCOUNTS',
            children: [
              ...auth.accounts.map((a) => _buildAccountRow(a, auth)),
              _buildAddAccountButton(auth),
            ],
          ),

          const SizedBox(height: 24),

          // PREFERENCES
          _systemSection(
            title: 'PREFERENCES',
            children: [
              ToggleRow(
                icon: Icons.notifications_active,
                label: 'Smart Notifications',
                value: _smartNotifications,
                onChanged: (v) => setState(() => _smartNotifications = v),
              ),
              const _SectionInlineDivider(),
              ToggleRow(
                icon: Icons.auto_awesome,
                label: 'AI Summaries',
                value: _aiSummaries,
                onChanged: (v) => setState(() => _aiSummaries = v),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // EMAIL SIGNATURES
          _systemSection(
            title: 'EMAIL SIGNATURES',
            children: [
              ToggleRow(
                icon: Icons.draw,
                label: 'Enable Signatures',
                value: _signatureEnabled,
                onChanged: (v) => setState(() => _signatureEnabled = v),
              ),
              if (_signatureEnabled)
                ...auth.accounts.map((a) => _buildSignatureRow(a)),
            ],
          ),

          const SizedBox(height: 24),

          // PRIVACY & SECURITY
          _systemSection(
            title: 'PRIVACY & SECURITY',
            children: [
              ToggleRow(
                icon: Icons.shield,
                label: 'Block Trackers',
                value: _blockTrackers,
                onChanged: (v) => setState(() => _blockTrackers = v),
              ),
              const _SectionInlineDivider(),
              ToggleRow(
                icon: Icons.visibility,
                label: 'Read Receipts',
                value: _readReceipts,
                onChanged: (v) => setState(() => _readReceipts = v),
              ),
              const _SectionInlineDivider(),
              _buildNavRow(
                icon: Icons.lock,
                label: 'Encryption',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const EncryptionView()),
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // APPEARANCE
          _systemSection(
            title: 'APPEARANCE',
            children: [
              _buildAppearancePicker(),
            ],
          ),

          const SizedBox(height: 24),

          // ABOUT
          _systemSection(
            title: 'ABOUT',
            children: [
              _buildNavRow(
                icon: Icons.info_outline,
                label: 'About VoidMail',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AboutView()),
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // SIGN OUT
          if (auth.isSignedIn) _buildSignOutButton(auth),
        ],
      ),
    );
  }

  // -- System Section: label divider + card-wrapped content --
  Widget _systemSection({
    required String title,
    required List<Widget> children,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: SectionDivider(label: title),
        ),
        const SizedBox(height: 10),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Container(
            decoration: BoxDecoration(
              color: VoidColors.bgCard,
              borderRadius: BorderRadius.circular(8),
            ),
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Column(children: children),
          ),
        ),
      ],
    );
  }

  // -- Account Row --
  Widget _buildAccountRow(UserAccount account, AuthService auth) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Column(
        children: [
          Row(
            children: [
              // Color dot
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: account.colorTag.color,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 14),
              InitialsAvatar(name: account.displayName, size: 40),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(account.label, style: Typo.body),
                        ),
                        const SizedBox(width: 6),
                        GestureDetector(
                          onTap: () => _showRenameDialog(account, auth),
                          child: const Icon(
                            Icons.edit,
                            size: 11,
                            color: VoidColors.textTertiary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      account.email,
                      style: Typo.mono.copyWith(color: VoidColors.textTertiary),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              if (account.isPrimary)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: VoidColors.bgCardHover,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    'PRIMARY',
                    style: Typo.mono.copyWith(
                      fontSize: 11,
                      color: VoidColors.textPrimary,
                      letterSpacing: 1,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          // Color picker row
          Padding(
            padding: const EdgeInsets.only(left: 26),
            child: Row(
              children: [
                Text(
                  'COLOR',
                  style: Typo.mono.copyWith(
                    fontSize: 11,
                    color: VoidColors.textTertiary,
                    letterSpacing: 1,
                  ),
                ),
                const Spacer(),
                ...AccountColor.values.map((c) => Padding(
                      padding: const EdgeInsets.only(left: 8),
                      child: GestureDetector(
                        onTap: () => auth.setAccountColor(account.email, c),
                        child: Container(
                          width: 24,
                          height: 24,
                          decoration: BoxDecoration(
                            color: c.color,
                            shape: BoxShape.circle,
                            border: account.colorTag == c
                                ? Border.all(color: VoidColors.textPrimary, width: 2)
                                : null,
                          ),
                        ),
                      ),
                    )),
              ],
            ),
          ),
        ],
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
    return GestureDetector(
      onTap: () => auth.signInWithGoogle(),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            const Icon(Icons.add, size: 14, color: VoidColors.textPrimary),
            const SizedBox(width: 10),
            Text('Add Account', style: Typo.body),
          ],
        ),
      ),
    );
  }

  // -- Signature Row (per-account, collapsible) --
  Widget _buildSignatureRow(UserAccount account) {
    _signatureControllers.putIfAbsent(
      account.email,
      () => TextEditingController(text: 'Sent from VoidMail'),
    );
    final isEditing = _editingSignatureAccount == account.email;

    return Column(
      children: [
        const _SectionInlineDivider(),
        GestureDetector(
          onTap: () => setState(() {
            _editingSignatureAccount = isEditing ? null : account.email;
          }),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: account.colorTag.color,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    account.email,
                    style: Typo.mono.copyWith(color: VoidColors.textSecondary),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Icon(
                  isEditing ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                  size: 12,
                  color: VoidColors.textTertiary,
                ),
              ],
            ),
          ),
        ),
        if (isEditing)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
            child: TextField(
              controller: _signatureControllers[account.email],
              maxLines: 4,
              style: Typo.subhead.copyWith(color: VoidColors.textPrimary),
              decoration: InputDecoration(
                filled: true,
                fillColor: VoidColors.bgDeep,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
      ],
    );
  }

  // -- Nav Row (icon + label + chevron) --
  Widget _buildNavRow({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Icon(icon, size: 16, color: VoidColors.textSecondary),
            const SizedBox(width: 14),
            Expanded(child: Text(label, style: Typo.body)),
            const Icon(
              Icons.chevron_right,
              size: 13,
              color: VoidColors.textTertiary,
            ),
          ],
        ),
      ),
    );
  }

  // -- Appearance Picker --
  Widget _buildAppearancePicker() {
    final themeNotifier = context.watch<ThemeModeNotifier>();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.dark_mode, size: 16, color: VoidColors.textSecondary),
              const SizedBox(width: 14),
              Text('Theme', style: Typo.body),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: SegmentedButton<String>(
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(value: 'dark', label: Text('Dark')),
                ButtonSegment(value: 'light', label: Text('Light')),
                ButtonSegment(value: 'system', label: Text('System')),
              ],
              selected: {themeNotifier.modeString},
              onSelectionChanged: (val) => themeNotifier.setMode(val.first),
              style: ButtonStyle(
                backgroundColor: WidgetStateProperty.resolveWith((states) {
                  if (states.contains(WidgetState.selected)) {
                    return VoidColors.textPrimary;
                  }
                  return VoidColors.bgDeep;
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

  // -- Sign Out Button --
  Widget _buildSignOutButton(AuthService auth) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: GestureDetector(
        onTap: () => _showSignOutConfirm(auth),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: VoidColors.accentPink,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Center(
            child: Text(
              'SIGN OUT',
              style: Typo.body.copyWith(
                color: VoidColors.bgDeep,
                letterSpacing: 1,
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showSignOutConfirm(AuthService auth) {
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
                style: Typo.body.copyWith(color: VoidColors.textSecondary)),
          ),
          TextButton(
            onPressed: () {
              auth.signOut();
              Navigator.pop(ctx);
            },
            child: Text('Sign Out',
                style: Typo.body.copyWith(color: VoidColors.accentPink)),
          ),
        ],
      ),
    );
  }
}

// Thin divider used between items inside a section card
class _SectionInlineDivider extends StatelessWidget {
  const _SectionInlineDivider();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(height: 0.5, color: VoidColors.border),
    );
  }
}
