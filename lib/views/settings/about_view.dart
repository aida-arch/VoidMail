import 'package:flutter/material.dart';
import '../../design_system/colors.dart';
import '../../design_system/typography.dart';
import '../../design_system/components.dart';

/// About View - Separate about page with logo, version, description, copyright
class AboutView extends StatelessWidget {
  const AboutView({super.key});

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
                  Text('ABOUT', style: Typo.metaLabel),
                  const Spacer(),
                  const SizedBox(width: 48),
                ],
              ),
            ),

            // Content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  children: [
                    const SizedBox(height: 40),

                    // Logo
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: VoidColors.bgCard,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: VoidColors.border,
                          width: 0.5,
                        ),
                      ),
                      child: const Icon(
                        Icons.mail_outline,
                        size: 40,
                        color: VoidColors.textPrimary,
                      ),
                    ),

                    const SizedBox(height: 24),

                    // App name
                    Text(
                      'VOIDMAIL',
                      style: Typo.title2.copyWith(
                        letterSpacing: 4,
                      ),
                    ),

                    const SizedBox(height: 4),

                    Text(
                      'by Neural Arc',
                      style: Typo.subhead.copyWith(
                        fontSize: 14,
                        color: VoidColors.accentPink,
                      ),
                    ),

                    const SizedBox(height: 8),

                    Text(
                      'Version 1.0.0 (Build 1.1)',
                      style: Typo.monoSmall,
                    ),

                    const SizedBox(height: 32),

                    // Description card
                    VoidCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'A dark, minimal, AI-powered email experience. '
                            'Built for focus.',
                            style: Typo.subhead.copyWith(height: 1.5),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Features
                    VoidCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'FEATURES',
                            style: Typo.metaLabel.copyWith(
                              color: VoidColors.accentSkyBlue,
                            ),
                          ),
                          const SizedBox(height: 16),
                          _featureRow(
                            Icons.auto_awesome,
                            'AI-Powered',
                            'Smart replies, summaries, and drafts',
                            VoidColors.accentSkyBlue,
                          ),
                          _featureRow(
                            Icons.dark_mode,
                            'Dark Brutalist Design',
                            'Minimal, focused interface',
                            VoidColors.textPrimary,
                          ),
                          _featureRow(
                            Icons.lock,
                            'End-to-End Encryption',
                            'Your emails, your privacy',
                            VoidColors.accentGreen,
                          ),
                          _featureRow(
                            Icons.translate,
                            'AI Translation',
                            'Translate emails to any language',
                            VoidColors.accentPink,
                          ),
                          _featureRow(
                            Icons.record_voice_over,
                            'Text-to-Speech',
                            'Listen to your emails',
                            VoidColors.accentYellow,
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Powered by
                    VoidCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'POWERED BY',
                            style: Typo.metaLabel,
                          ),
                          const SizedBox(height: 12),
                          _poweredByRow('Google Gemini 2.0 Flash', 'AI Engine'),
                          _poweredByRow('Deepgram', 'Text-to-Speech'),
                          _poweredByRow('Gmail API', 'Email Backend'),
                          _poweredByRow('Google Calendar', 'Calendar'),
                        ],
                      ),
                    ),

                    const SizedBox(height: 32),

                    // Copyright
                    Text(
                      '\u00a9 2025 Neural Arc. All rights reserved.',
                      style: Typo.monoSmall,
                    ),

                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _featureRow(
      IconData icon, String title, String subtitle, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
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
                Text(
                  title,
                  style: Typo.headline.copyWith(fontSize: 14),
                ),
                Text(
                  subtitle,
                  style: Typo.subhead.copyWith(fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _poweredByRow(String name, String role) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Text(
            name,
            style: Typo.body.copyWith(fontSize: 14),
          ),
          const Spacer(),
          Text(
            role,
            style: Typo.monoSmall,
          ),
        ],
      ),
    );
  }
}
