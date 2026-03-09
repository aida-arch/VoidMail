import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/email.dart';
import 'backend_service.dart';
import 'notification_service.dart';
import 'in_app_notification_manager.dart';

/// Gmail API Service - Fetches, sends, and modifies emails
class GmailService extends ChangeNotifier {
  final BackendService _backend = BackendService();

  List<Email> _emails = [];
  bool _isLoading = false;
  bool _isSyncing = false;
  String? _error;
  Timer? _syncTimer;
  final Set<String> _knownEmailIds = {};

  List<Email> get emails => _emails;
  bool get isLoading => _isLoading;
  bool get isSyncing => _isSyncing;
  String? get error => _error;

  int get unreadCount => _emails.where((e) => !e.isRead).length;
  int get starredCount => _emails.where((e) => e.isStarred).length;
  int get attachmentCount =>
      _emails.where((e) => e.attachments.isNotEmpty).length;

  /// Start auto-sync timer (every 45 seconds)
  void startAutoSync() {
    _syncTimer?.cancel();
    _syncTimer = Timer.periodic(const Duration(seconds: 45), (_) {
      syncEmails();
    });
  }

  void stopAutoSync() {
    _syncTimer?.cancel();
    _syncTimer = null;
  }

  /// Fetch emails from API
  Future<void> fetchEmails({String? query, String? accountEmail}) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final params = <String, String>{};
      if (query != null && query.isNotEmpty) params['q'] = query;
      params['maxResults'] = '50';

      final response = await _backend.get('/api/gmail/messages', queryParams: params);

      final messages = response['messages'] as List? ?? response['data'] as List? ?? [];
      _emails = messages.map((m) {
        final email = Email.fromJson(m as Map<String, dynamic>);
        _knownEmailIds.add(email.id);
        return email;
      }).toList();

      _emails.sort((a, b) => b.date.compareTo(a.date));
      await _persistKnownIds();

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Sync emails (light refresh)
  Future<List<Email>> syncEmails() async {
    if (_isSyncing) return [];
    _isSyncing = true;
    notifyListeners();

    try {
      final response = await _backend.get('/api/gmail/messages', queryParams: {
        'maxResults': '20',
      });

      final messages = response['messages'] as List? ?? response['data'] as List? ?? [];
      final newEmails = <Email>[];

      for (final m in messages) {
        final email = Email.fromJson(m as Map<String, dynamic>);
        if (!_knownEmailIds.contains(email.id)) {
          newEmails.add(email);
          _knownEmailIds.add(email.id);
        }
      }

      if (newEmails.isNotEmpty) {
        _emails.insertAll(0, newEmails);
        _emails.sort((a, b) => b.date.compareTo(a.date));

        final notificationService = NotificationService();
        final inAppManager = InAppNotificationManager();

        for (final email in newEmails) {
          // System notification
          notificationService.showEmailNotification(
            emailId: email.id,
            senderName: email.from.displayName,
            subject: email.subject,
          );

          // In-app banner notification
          inAppManager.show(
            senderName: email.from.displayName,
            subject: email.subject,
            snippet: email.snippet,
            emailId: email.id,
          );
        }
        await _persistKnownIds();
      }

      _isSyncing = false;
      notifyListeners();
      return newEmails;
    } catch (e) {
      _isSyncing = false;
      notifyListeners();
      return [];
    }
  }

  /// Fetch single email detail
  Future<Email?> fetchEmailDetail(String id) async {
    try {
      final response = await _backend.get('/api/gmail/messages/$id');
      final message = response['message'] as Map<String, dynamic>? ?? response;
      return Email.fromJson(message);
    } catch (e) {
      debugPrint('Error fetching email detail: $e');
      return null;
    }
  }

  /// Toggle read/unread
  Future<void> toggleRead(String emailId) async {
    final index = _emails.indexWhere((e) => e.id == emailId);
    if (index == -1) return;

    final email = _emails[index];
    email.isRead = !email.isRead;
    notifyListeners();

    try {
      if (email.isRead) {
        await _backend.post('/api/gmail/messages/$emailId/modify', body: {
          'removeLabelIds': ['UNREAD'],
        });
      } else {
        await _backend.post('/api/gmail/messages/$emailId/modify', body: {
          'addLabelIds': ['UNREAD'],
        });
      }
    } catch (e) {
      // Revert on error
      email.isRead = !email.isRead;
      notifyListeners();
    }
  }

  /// Star/unstar email
  Future<void> toggleStar(String emailId) async {
    final index = _emails.indexWhere((e) => e.id == emailId);
    if (index == -1) return;

    final email = _emails[index];
    email.isStarred = !email.isStarred;
    notifyListeners();

    try {
      if (email.isStarred) {
        await _backend.post('/api/gmail/messages/$emailId/modify', body: {
          'addLabelIds': ['STARRED'],
        });
      } else {
        await _backend.post('/api/gmail/messages/$emailId/modify', body: {
          'removeLabelIds': ['STARRED'],
        });
      }
    } catch (e) {
      email.isStarred = !email.isStarred;
      notifyListeners();
    }
  }

  /// Delete email (move to trash)
  Future<void> deleteEmail(String emailId) async {
    final index = _emails.indexWhere((e) => e.id == emailId);
    if (index == -1) return;

    final removed = _emails.removeAt(index);
    _knownEmailIds.remove(emailId);
    notifyListeners();

    try {
      await _backend.delete('/api/gmail/messages/$emailId');
    } catch (e) {
      _emails.insert(index, removed);
      _knownEmailIds.add(emailId);
      notifyListeners();
    }
  }

  /// Archive email
  Future<void> archiveEmail(String emailId) async {
    try {
      await _backend.post('/api/gmail/messages/$emailId/modify', body: {
        'removeLabelIds': ['INBOX'],
      });
      _emails.removeWhere((e) => e.id == emailId);
      notifyListeners();
    } catch (e) {
      debugPrint('Error archiving: $e');
    }
  }

  /// Send email
  Future<bool> sendEmail({
    required String to,
    required String subject,
    required String body,
    String? replyToId,
    String? threadId,
    String? fromEmail,
  }) async {
    try {
      await _backend.post('/api/gmail/messages/send', body: {
        'to': to,
        'subject': subject,
        'body': body,
        if (replyToId != null) 'replyToMessageId': replyToId,
        if (threadId != null) 'threadId': threadId,
        if (fromEmail != null) 'fromEmail': fromEmail,
      });
      return true;
    } catch (e) {
      debugPrint('Error sending email: $e');
      return false;
    }
  }

  /// Get emails filtered by category
  List<Email> getEmailsByCategory(EmailCategory? category) {
    if (category == null) return _emails;
    return _emails.where((e) => e.category == category).toList();
  }

  /// Get emails filtered by account
  List<Email> getEmailsByAccount(String? accountEmail) {
    if (accountEmail == null) return _emails;
    return _emails.where((e) => e.accountEmail == accountEmail).toList();
  }

  /// Get grouped emails by date
  Map<String, List<Email>> get groupedEmails {
    final Map<String, List<Email>> grouped = {};
    for (final email in _emails) {
      final key = email.dateGroupKey;
      grouped.putIfAbsent(key, () => []).add(email);
    }
    return grouped;
  }

  /// Generate mock emails for testing
  void loadMockEmails() {
    _emails = _generateMockEmails();
    _isLoading = false;
    notifyListeners();
  }

  List<Email> _generateMockEmails() {
    final now = DateTime.now();
    return [
      Email(
        id: '1',
        threadId: 't1',
        from: Contact(id: '1', name: 'Sarah Chen', email: 'sarah@company.com'),
        to: [Contact(id: 'me', name: 'Me', email: 'me@gmail.com')],
        subject: 'Q4 Product Roadmap Review',
        snippet: 'Hey team, I\'ve updated the product roadmap with the latest priorities for Q4. Please review the attached document and share your feedback before...',
        body: 'Hey team,\n\nI\'ve updated the product roadmap with the latest priorities for Q4. Please review the attached document and share your feedback before our meeting on Friday.\n\nKey highlights:\n- Launch new dashboard by October\n- API v2 migration complete by November\n- Mobile app redesign kicks off December\n\nLet me know if you have any questions.\n\nBest,\nSarah',
        date: now.subtract(const Duration(minutes: 15)),
        isRead: false,
        isStarred: true,
        category: EmailCategory.priority,
        attachments: [
          Attachment(
            id: 'a1',
            name: 'Q4_Roadmap.pdf',
            mimeType: 'application/pdf',
            size: 2048576,
          ),
        ],
      ),
      Email(
        id: '2',
        threadId: 't2',
        from: Contact(id: '2', name: 'GitHub', email: 'notifications@github.com'),
        to: [Contact(id: 'me', name: 'Me', email: 'me@gmail.com')],
        subject: '[void-mail] Pull request #42: Add dark mode support',
        snippet: 'marcus-dev requested your review on pull request #42. Changes include theme switching, color palette updates, and CSS variable implementation...',
        body: 'marcus-dev requested your review on pull request #42.\n\nAdd dark mode support\n\nChanges:\n- Theme switching logic\n- Color palette updates\n- CSS variable implementation\n- Persistent user preference storage\n\nView on GitHub: https://github.com/void-mail/pull/42',
        date: now.subtract(const Duration(hours: 1)),
        isRead: false,
        category: EmailCategory.updates,
      ),
      Email(
        id: '3',
        threadId: 't3',
        from: Contact(id: '3', name: 'Alex Rivera', email: 'alex@startup.io'),
        to: [Contact(id: 'me', name: 'Me', email: 'me@gmail.com')],
        subject: 'Coffee chat next week?',
        snippet: 'Would love to catch up and hear about what you\'ve been working on. Are you free Tuesday or Wednesday afternoon? There\'s a new cafe on...',
        body: 'Hey!\n\nWould love to catch up and hear about what you\'ve been working on. Are you free Tuesday or Wednesday afternoon? There\'s a new cafe on Main Street that\'s supposed to be great.\n\nLet me know!\nAlex',
        date: now.subtract(const Duration(hours: 3)),
        isRead: true,
        category: EmailCategory.primary,
      ),
      Email(
        id: '4',
        threadId: 't4',
        from: Contact(id: '4', name: 'Notion', email: 'team@notion.so'),
        to: [Contact(id: 'me', name: 'Me', email: 'me@gmail.com')],
        subject: 'What\'s new in Notion: AI-powered templates',
        snippet: 'Discover our latest AI features that help you create documents faster. New templates for project management, meeting notes, and more...',
        body: 'Discover our latest AI features that help you create documents faster.\n\nNew templates:\n- Project management\n- Meeting notes\n- Sprint planning\n- Product specs\n\nTry them today!',
        date: now.subtract(const Duration(hours: 5)),
        isRead: true,
        category: EmailCategory.newsletters,
      ),
      Email(
        id: '5',
        threadId: 't5',
        from: Contact(id: '5', name: 'David Kim', email: 'david@design.co'),
        to: [Contact(id: 'me', name: 'Me', email: 'me@gmail.com')],
        subject: 'Updated wireframes for the dashboard',
        snippet: 'Attached are the updated wireframes incorporating the feedback from last week\'s design review. Main changes include simplified navigation...',
        body: 'Hi,\n\nAttached are the updated wireframes incorporating the feedback from last week\'s design review.\n\nMain changes:\n- Simplified navigation\n- Consolidated sidebar\n- New card-based layout for metrics\n- Updated color scheme\n\nLet me know what you think!\nDavid',
        date: now.subtract(const Duration(days: 1, hours: 2)),
        isRead: false,
        isStarred: true,
        category: EmailCategory.priority,
        attachments: [
          Attachment(
            id: 'a2',
            name: 'Dashboard_V3.fig',
            mimeType: 'application/figma',
            size: 5242880,
          ),
          Attachment(
            id: 'a3',
            name: 'Navigation_Flow.png',
            mimeType: 'image/png',
            size: 1048576,
          ),
        ],
      ),
      Email(
        id: '6',
        threadId: 't6',
        from: Contact(id: '6', name: 'Stripe', email: 'notifications@stripe.com'),
        to: [Contact(id: 'me', name: 'Me', email: 'me@gmail.com')],
        subject: 'Your monthly invoice is ready',
        snippet: 'Your invoice for March 2025 is now available. Total amount: \$149.00. View your invoice and payment details in your Stripe dashboard...',
        body: 'Your invoice for March 2025 is now available.\n\nTotal: \$149.00\nPlan: Pro\nBilling period: Mar 1 - Mar 31\n\nView in dashboard.',
        date: now.subtract(const Duration(days: 1, hours: 8)),
        isRead: true,
        category: EmailCategory.updates,
      ),
      Email(
        id: '7',
        threadId: 't7',
        from: Contact(id: '7', name: 'Maria Santos', email: 'maria@agency.com'),
        to: [Contact(id: 'me', name: 'Me', email: 'me@gmail.com')],
        subject: 'Re: Brand guidelines document',
        snippet: 'Thanks for sharing! I\'ve added some comments on the typography section. The color palette looks great. One suggestion - could we explore a slightly...',
        body: 'Thanks for sharing! I\'ve added some comments on the typography section.\n\nThe color palette looks great. One suggestion - could we explore a slightly warmer tone for the secondary color? I think it would complement the primary better.\n\nAlso, the logo variations look perfect.\n\nBest,\nMaria',
        date: now.subtract(const Duration(days: 2)),
        isRead: true,
        category: EmailCategory.primary,
      ),
      Email(
        id: '8',
        threadId: 't8',
        from: Contact(id: '8', name: 'Linear', email: 'updates@linear.app'),
        to: [Contact(id: 'me', name: 'Me', email: 'me@gmail.com')],
        subject: 'Weekly digest: 12 issues closed, 5 new',
        snippet: 'Your team had a productive week! 12 issues were closed and 5 new ones were created. Top contributors: Sarah (4), Marcus (3), David (3)...',
        body: 'Weekly team digest:\n\n12 issues closed\n5 new issues\n\nTop contributors:\n- Sarah (4 closed)\n- Marcus (3 closed)\n- David (3 closed)\n- Alex (2 closed)',
        date: now.subtract(const Duration(days: 3)),
        isRead: true,
        category: EmailCategory.updates,
      ),
    ];
  }

  Future<void> _persistKnownIds() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
        'voidmail_known_email_ids', _knownEmailIds.toList());
  }

  Future<void> loadKnownIds() async {
    final prefs = await SharedPreferences.getInstance();
    final ids = prefs.getStringList('voidmail_known_email_ids');
    if (ids != null) _knownEmailIds.addAll(ids);
  }

  @override
  void dispose() {
    stopAutoSync();
    super.dispose();
  }
}
