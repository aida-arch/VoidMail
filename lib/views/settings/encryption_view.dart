import 'package:flutter/material.dart';
import '../../design_system/colors.dart';
import '../../design_system/typography.dart';
import '../../design_system/components.dart';

/// Encryption Settings View
/// Dedicated page for managing encryption preferences.
class EncryptionView extends StatefulWidget {
  const EncryptionView({super.key});

  @override
  State<EncryptionView> createState() => _EncryptionViewState();
}

class _EncryptionViewState extends State<EncryptionView> {
  bool _endToEndEncryption = true;
  bool _encryptAttachments = true;
  bool _encryptDrafts = false;
  bool _autoDeleteKeys = false;
  String _encryptionLevel = 'standard';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: VoidColors.bgDeep,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.arrow_back,
                        color: VoidColors.textPrimary),
                  ),
                  const Spacer(),
                  Text('ENCRYPTION', style: Typo.metaLabel),
                  const Spacer(),
                  const SizedBox(width: 48),
                ],
              ),
            ),

            // Content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.only(bottom: 40),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 16),

                    // Status card
                    Padding(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 20),
                      child: VoidCard(
                        child: Row(
                          children: [
                            Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                color: VoidColors.accentGreen
                                    .withValues(alpha: 0.15),
                                borderRadius:
                                    BorderRadius.circular(12),
                              ),
                              child: const Icon(
                                Icons.lock,
                                size: 24,
                                color: VoidColors.accentGreen,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'End-to-End Encrypted',
                                    style: Typo.headline,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Your emails are protected with AES-256 encryption',
                                    style: Typo.subhead.copyWith(
                                      fontSize: 13,
                                      color:
                                          VoidColors.textTertiary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Encryption settings
                    const SectionDivider(
                        label: 'ENCRYPTION SETTINGS'),

                    ToggleRow(
                      icon: Icons.enhanced_encryption,
                      label: 'End-to-End Encryption',
                      value: _endToEndEncryption,
                      onChanged: (v) =>
                          setState(() => _endToEndEncryption = v),
                    ),

                    ToggleRow(
                      icon: Icons.attach_file,
                      label: 'Encrypt Attachments',
                      value: _encryptAttachments,
                      onChanged: (v) =>
                          setState(() => _encryptAttachments = v),
                    ),

                    ToggleRow(
                      icon: Icons.drafts,
                      label: 'Encrypt Drafts',
                      value: _encryptDrafts,
                      onChanged: (v) =>
                          setState(() => _encryptDrafts = v),
                    ),

                    ToggleRow(
                      icon: Icons.auto_delete,
                      label: 'Auto-Delete Expired Keys',
                      value: _autoDeleteKeys,
                      onChanged: (v) =>
                          setState(() => _autoDeleteKeys = v),
                    ),

                    const SizedBox(height: 24),

                    // Encryption level
                    const SectionDivider(label: 'ENCRYPTION LEVEL'),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 8),
                      child: Row(
                        children: [
                          const Icon(Icons.security,
                              size: 16,
                              color: VoidColors.textSecondary),
                          const SizedBox(width: 12),
                          Text('Level', style: Typo.body),
                          const SizedBox(width: 12),
                          Expanded(
                            flex: 3,
                            child: SegmentedButton<String>(
                              showSelectedIcon: false,
                              segments: const [
                                ButtonSegment(
                                    value: 'standard',
                                    label: Text('Standard')),
                                ButtonSegment(
                                    value: 'high',
                                    label: Text('High')),
                                ButtonSegment(
                                    value: 'maximum',
                                    label: Text('Maximum')),
                              ],
                              selected: {_encryptionLevel},
                              onSelectionChanged: (val) => setState(
                                  () => _encryptionLevel = val.first),
                              style: ButtonStyle(
                                backgroundColor: WidgetStateProperty
                                    .resolveWith((states) {
                                  if (states.contains(
                                      WidgetState.selected)) {
                                    return VoidColors.textPrimary;
                                  }
                                  return VoidColors.bgCard;
                                }),
                                foregroundColor: WidgetStateProperty
                                    .resolveWith((states) {
                                  if (states.contains(
                                      WidgetState.selected)) {
                                    return VoidColors.textInverse;
                                  }
                                  return VoidColors.textSecondary;
                                }),
                                side: WidgetStateProperty.all(
                                  const BorderSide(
                                      color: VoidColors.border,
                                      width: 0.5),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Info section
                    const SectionDivider(label: 'ABOUT ENCRYPTION'),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20),
                      child: VoidCard(
                        child: Column(
                          crossAxisAlignment:
                              CrossAxisAlignment.start,
                          children: [
                            Text(
                              'How it works',
                              style: Typo.headline
                                  .copyWith(fontSize: 15),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'VoidMail uses industry-standard AES-256 encryption '
                              'to protect your emails. When end-to-end encryption '
                              'is enabled, only you and the recipient can read '
                              'the message content. Keys are generated locally '
                              'and never leave your device.',
                              style: Typo.subhead
                                  .copyWith(height: 1.5),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
