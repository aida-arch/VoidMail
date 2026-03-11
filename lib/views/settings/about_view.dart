import 'package:flutter/material.dart';
import '../../design_system/colors.dart';
import '../../design_system/typography.dart';
import '../../design_system/components.dart';

/// About View - Logo, version, description, copyright
class AboutView extends StatelessWidget {
  const AboutView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: VoidColors.bgDeep,
      body: SafeArea(
        child: Column(
          children: [
            // Header bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
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
                child: Column(
                  children: [
                    const SizedBox(height: 40),

                    // Logo
                    const Icon(
                      Icons.mail_outline,
                      size: 64,
                      color: VoidColors.textPrimary,
                    ),

                    const SizedBox(height: 24),

                    // Title
                    Text(
                      'VoidMail',
                      style: Typo.title2.copyWith(letterSpacing: -0.5),
                    ),

                    const SizedBox(height: 4),

                    Text(
                      'Version 1.1',
                      style: Typo.mono.copyWith(
                        color: VoidColors.textTertiary,
                        letterSpacing: 1,
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Divider
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 40),
                      child: Divider(height: 0.5, color: VoidColors.border),
                    ),

                    const SizedBox(height: 24),

                    // Crafted by card
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: VoidCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'CRAFTED BY NEURAL ARC',
                              style: Typo.meta.copyWith(
                                color: VoidColors.accentSkyBlue,
                                letterSpacing: 2,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'Neural Arc is a forward-thinking technology company '
                              'specializing in intelligent software solutions. '
                              'Powered by the Helium AI engine, Neural Arc builds '
                              'products that blend cutting-edge artificial intelligence '
                              'with elegant user experiences. VoidMail is our flagship '
                              'communication platform, designed to bring clarity to '
                              'your inbox through smart automation, privacy-first '
                              'architecture, and a beautifully minimal interface.',
                              style: Typo.subhead.copyWith(
                                height: 1.6,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 40),

                    // Copyright
                    Text(
                      '\u00a9 2025 Neural Arc. All rights reserved.',
                      style: Typo.mono.copyWith(
                        color: VoidColors.textTertiary,
                        letterSpacing: 0.5,
                      ),
                      textAlign: TextAlign.center,
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
}
