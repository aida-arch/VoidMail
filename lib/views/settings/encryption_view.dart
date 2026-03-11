import 'package:flutter/material.dart';
import '../../design_system/colors.dart';
import '../../design_system/typography.dart';

/// Encryption info view — matches reference's minimal layout
class EncryptionView extends StatelessWidget {
  const EncryptionView({super.key});

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
                  Text('ENCRYPTION', style: Typo.metaLabel),
                  const Spacer(),
                  const SizedBox(width: 48),
                ],
              ),
            ),

            // Content
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  children: [
                    const SizedBox(height: 40),
                    const Icon(
                      Icons.lock,
                      size: 48,
                      color: VoidColors.textSecondary,
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'ENCRYPTION',
                      style: Typo.title3.copyWith(letterSpacing: 2),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Your emails are encrypted on-device.\nNo data is stored on our servers.',
                      style: Typo.subhead.copyWith(
                        color: VoidColors.textTertiary,
                        height: 1.6,
                      ),
                      textAlign: TextAlign.center,
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
