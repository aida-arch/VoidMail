import 'package:flutter/material.dart';
import 'colors.dart';

/// VoidMail Typography System
class Typo {
  Typo._();

  // Display - 66pt heavy
  static TextStyle display = const TextStyle(
    fontSize: 66,
    fontWeight: FontWeight.w900,
    color: VoidColors.textPrimary,
    letterSpacing: -2,
    height: 1.0,
  );

  // Title - 42pt heavy
  static TextStyle title = const TextStyle(
    fontSize: 42,
    fontWeight: FontWeight.w900,
    color: VoidColors.textPrimary,
    letterSpacing: -1.5,
    height: 1.1,
  );

  // Title2 - 32pt heavy
  static TextStyle title2 = const TextStyle(
    fontSize: 32,
    fontWeight: FontWeight.w900,
    color: VoidColors.textPrimary,
    letterSpacing: -1,
    height: 1.1,
  );

  // Title3 - 24pt bold
  static TextStyle title3 = const TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.bold,
    color: VoidColors.textPrimary,
    height: 1.2,
  );

  // Headline - 17pt bold
  static TextStyle headline = const TextStyle(
    fontSize: 17,
    fontWeight: FontWeight.bold,
    color: VoidColors.textPrimary,
    height: 1.3,
  );

  // Body - 16pt medium
  static TextStyle body = const TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w500,
    color: VoidColors.textPrimary,
    height: 1.5,
  );

  // Subhead - 15pt regular
  static TextStyle subhead = const TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w400,
    color: VoidColors.textSecondary,
    height: 1.4,
  );

  // Meta - 15pt medium, 2px tracking
  static TextStyle meta = const TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w500,
    color: VoidColors.textTertiary,
    letterSpacing: 2,
    height: 1.3,
  );

  // Mono - 15pt monospace
  static TextStyle mono = const TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w400,
    fontFamily: 'monospace',
    color: VoidColors.textSecondary,
    height: 1.3,
  );

  // Mono Small - 13pt monospace
  static TextStyle monoSmall = const TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w400,
    fontFamily: 'monospace',
    color: VoidColors.textTertiary,
    height: 1.3,
  );

  // Caption - 12pt
  static TextStyle caption = const TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w400,
    color: VoidColors.textTertiary,
    height: 1.3,
  );

  // Display Title Style - uppercase with tight tracking
  static TextStyle displayTitle = display.copyWith(
    letterSpacing: -3,
  );

  // Screen Title
  static TextStyle screenTitle = title.copyWith(
    letterSpacing: -1,
  );

  // Meta Label - uppercase mono
  static TextStyle metaLabel = meta.copyWith(
    fontSize: 12,
    fontFamily: 'monospace',
    letterSpacing: 3,
  );

  // Section Label
  static TextStyle sectionLabel = meta.copyWith(
    fontSize: 13,
    letterSpacing: 2.5,
  );

  // Inbox Title - 48pt heavy (between title and display)
  static TextStyle inboxTitle = const TextStyle(
    fontSize: 48,
    fontWeight: FontWeight.w900,
    color: VoidColors.textPrimary,
    letterSpacing: -1.5,
    height: 1.0,
  );
}
