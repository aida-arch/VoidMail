import 'package:flutter/material.dart';
import '../design_system/colors.dart';

/// Email Category
enum EmailCategory {
  primary('Primary', Icons.inbox, VoidColors.textPrimary),
  priority('Priority', Icons.flag, VoidColors.accentPink),
  updates('Updates', Icons.notifications, VoidColors.accentSkyBlue),
  newsletters('Newsletters', Icons.newspaper, VoidColors.accentYellow);

  final String label;
  final IconData icon;
  final Color color;

  const EmailCategory(this.label, this.icon, this.color);
}

/// Contact
class Contact {
  final String id;
  final String name;
  final String email;

  Contact({
    required this.id,
    required this.name,
    required this.email,
  });

  String get displayName => name.isNotEmpty ? name : email;

  String get initials {
    final parts = name.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name.isNotEmpty ? name[0].toUpperCase() : '?';
  }

  factory Contact.fromJson(Map<String, dynamic> json) {
    return Contact(
      id: json['id'] ?? json['email'] ?? '',
      name: json['name'] ?? '',
      email: json['email'] ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'email': email,
      };
}

/// Attachment
class Attachment {
  final String id;
  final String name;
  final String mimeType;
  final int size;
  final String? attachmentId;
  final String? messageId;

  Attachment({
    required this.id,
    required this.name,
    required this.mimeType,
    required this.size,
    this.attachmentId,
    this.messageId,
  });

  String get formattedSize {
    if (size < 1024) return '$size B';
    if (size < 1024 * 1024) return '${(size / 1024).toStringAsFixed(1)} KB';
    return '${(size / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  IconData get icon {
    if (mimeType.startsWith('image/')) return Icons.image;
    if (mimeType.contains('pdf')) return Icons.picture_as_pdf;
    if (mimeType.contains('word') || mimeType.contains('document')) {
      return Icons.description;
    }
    if (mimeType.contains('sheet') || mimeType.contains('excel')) {
      return Icons.table_chart;
    }
    if (mimeType.contains('presentation') || mimeType.contains('powerpoint')) {
      return Icons.slideshow;
    }
    if (mimeType.startsWith('video/')) return Icons.videocam;
    if (mimeType.startsWith('audio/')) return Icons.audiotrack;
    if (mimeType.contains('zip') || mimeType.contains('archive')) {
      return Icons.folder_zip;
    }
    return Icons.attach_file;
  }

  bool get isDownloadable => attachmentId != null && messageId != null;

  factory Attachment.fromJson(Map<String, dynamic> json, {String? emailId}) {
    return Attachment(
      id: json['id'] ?? json['attachmentId'] ?? '',
      name: json['name'] ?? json['filename'] ?? 'Untitled',
      mimeType: json['mimeType'] ?? 'application/octet-stream',
      size: json['size'] ?? 0,
      attachmentId: json['attachmentId'] ?? json['body']?['attachmentId'] ?? json['id'],
      messageId: json['messageId'] ?? emailId,
    );
  }
}

/// Swipe Action
enum SwipeAction {
  archive('Archive', Icons.archive, VoidColors.accentSkyBlue),
  delete('Delete', Icons.delete, VoidColors.accentPink),
  snooze('Snooze', Icons.snooze, VoidColors.accentYellow),
  markRead('Mark Read', Icons.mark_email_read, VoidColors.accentSkyBlue),
  star('Star', Icons.star, VoidColors.accentYellow);

  final String label;
  final IconData icon;
  final Color color;

  const SwipeAction(this.label, this.icon, this.color);
}

/// Email Model
class Email {
  final String id;
  final String threadId;
  final Contact from;
  final List<Contact> to;
  final List<Contact> cc;
  final String subject;
  final String snippet;
  final String body;
  final DateTime date;
  bool isRead;
  bool isStarred;
  bool isSnoozed;
  final EmailCategory category;
  final List<String> labels;
  final List<Attachment> attachments;
  String? aiSummary;
  bool isAIPriority;
  final String? accountEmail;

  Email({
    required this.id,
    required this.threadId,
    required this.from,
    required this.to,
    this.cc = const [],
    required this.subject,
    required this.snippet,
    this.body = '',
    required this.date,
    this.isRead = false,
    this.isStarred = false,
    this.isSnoozed = false,
    this.category = EmailCategory.primary,
    this.labels = const [],
    this.attachments = const [],
    this.aiSummary,
    this.isAIPriority = false,
    this.accountEmail,
  });

  String get relativeDate {
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inMinutes < 1) return 'now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    if (diff.inHours < 24) return '${diff.inHours}h';
    if (diff.inDays == 1) return 'Yesterday';
    if (diff.inDays < 7) return '${diff.inDays}d';
    return '${date.month}/${date.day}';
  }

  String get dateGroupKey {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final emailDay = DateTime(date.year, date.month, date.day);

    if (emailDay == today) return 'TODAY';
    if (emailDay == today.subtract(const Duration(days: 1))) return 'YESTERDAY';
    return '${_monthName(date.month)} ${date.day}, ${date.year}';
  }

  static String _monthName(int month) {
    const names = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return names[month - 1];
  }

  factory Email.fromJson(Map<String, dynamic> json) {
    EmailCategory category = EmailCategory.primary;
    final labels = List<String>.from(json['labels'] ?? []);
    if (labels.contains('CATEGORY_UPDATES')) {
      category = EmailCategory.updates;
    } else if (labels.contains('CATEGORY_PROMOTIONS')) {
      category = EmailCategory.newsletters;
    } else if (labels.contains('IMPORTANT') ||
        labels.contains('PRIORITY_INBOX')) {
      category = EmailCategory.priority;
    }

    return Email(
      id: json['id'] ?? '',
      threadId: json['threadId'] ?? '',
      from: Contact.fromJson(json['from'] ?? {'name': '', 'email': ''}),
      to: (json['to'] as List?)
              ?.map((c) => Contact.fromJson(c))
              .toList() ??
          [],
      cc: (json['cc'] as List?)
              ?.map((c) => Contact.fromJson(c))
              .toList() ??
          [],
      subject: json['subject'] ?? '(No Subject)',
      snippet: json['snippet'] ?? '',
      body: json['body'] ?? '',
      date: json['date'] != null
          ? DateTime.tryParse(json['date']) ?? DateTime.now()
          : DateTime.now(),
      isRead: !((json['labels'] as List?)?.contains('UNREAD') ?? false),
      isStarred: (json['labels'] as List?)?.contains('STARRED') ?? false,
      category: category,
      labels: labels,
      attachments: (json['attachments'] as List?)
              ?.map((a) => Attachment.fromJson(a as Map<String, dynamic>, emailId: json['id']))
              .toList() ??
          [],
      accountEmail: json['accountEmail'],
    );
  }
}

/// Draft Model
class Draft {
  String to;
  String cc;
  String bcc;
  String subject;
  String body;
  String? replyToId;
  String? threadId;
  String? fromEmail;
  DateTime? scheduledDate;
  List<String> attachmentPaths;

  Draft({
    this.to = '',
    this.cc = '',
    this.bcc = '',
    this.subject = '',
    this.body = '',
    this.replyToId,
    this.threadId,
    this.fromEmail,
    this.scheduledDate,
    this.attachmentPaths = const [],
  });
}
