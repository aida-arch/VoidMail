import 'package:flutter/material.dart';
import '../design_system/colors.dart';

/// Account Color Tags
enum AccountColor {
  pink('Pink', VoidColors.accentPink, Icons.circle),
  green('Green', VoidColors.accentGreen, Icons.circle),
  skyBlue('Sky Blue', VoidColors.accentSkyBlue, Icons.circle),
  yellow('Yellow', VoidColors.accentYellow, Icons.circle),
  white('White', VoidColors.textPrimary, Icons.circle);

  final String label;
  final Color color;
  final IconData icon;

  const AccountColor(this.label, this.color, this.icon);
}

/// Account Provider
enum AccountProvider {
  google('Google', Icons.g_mobiledata),
  imap('IMAP', Icons.email);

  final String label;
  final IconData icon;

  const AccountProvider(this.label, this.icon);
}

/// User Account
class UserAccount {
  final String id;
  final String email;
  final String displayName;
  final String? photoURL;
  final AccountProvider provider;
  final bool isPrimary;
  String label;
  AccountColor colorTag;
  String? accessToken;
  String? refreshToken;

  UserAccount({
    required this.id,
    required this.email,
    required this.displayName,
    this.photoURL,
    this.provider = AccountProvider.google,
    this.isPrimary = false,
    String? label,
    this.colorTag = AccountColor.pink,
    this.accessToken,
    this.refreshToken,
  }) : label = label ?? displayName;

  factory UserAccount.fromJson(Map<String, dynamic> json) {
    return UserAccount(
      id: json['id'] ?? '',
      email: json['email'] ?? '',
      displayName: json['displayName'] ?? json['name'] ?? '',
      photoURL: json['photoURL'] ?? json['picture'],
      provider: AccountProvider.google,
      isPrimary: json['isPrimary'] ?? false,
      label: json['label'],
      accessToken: json['accessToken'],
      refreshToken: json['refreshToken'],
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'email': email,
        'displayName': displayName,
        'photoURL': photoURL,
        'provider': provider.name,
        'isPrimary': isPrimary,
        'label': label,
        'colorTag': colorTag.name,
        'accessToken': accessToken,
        'refreshToken': refreshToken,
      };
}

/// AI Alert Types
enum AlertType {
  awaitingReply('Awaiting Reply', Icons.reply, VoidColors.accentPink),
  upcomingMeeting('Upcoming Meeting', Icons.event, VoidColors.accentSkyBlue),
  followUp('Follow Up', Icons.schedule, VoidColors.accentYellow),
  newSender('New Sender', Icons.person_add, VoidColors.accentYellow);

  final String label;
  final IconData icon;
  final Color color;

  const AlertType(this.label, this.icon, this.color);
}

/// AI Alert
class AIAlert {
  final String id;
  final AlertType type;
  final String title;
  final String subtitle;
  final String? emailId;
  final String? eventId;
  final DateTime date;

  AIAlert({
    required this.id,
    required this.type,
    required this.title,
    required this.subtitle,
    this.emailId,
    this.eventId,
    DateTime? date,
  }) : date = date ?? DateTime.now();

  IconData get icon => type.icon;
  Color get color => type.color;
}
