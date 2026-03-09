import 'package:flutter/foundation.dart';
import 'backend_service.dart';

/// AI Features via Gemini 2.0 Flash
class GeminiService {
  final BackendService _backend = BackendService();

  /// Summarize an email in 1-2 sentences
  Future<String?> summarizeEmail({
    required String subject,
    required String body,
    required String from,
  }) async {
    try {
      final response = await _backend.post('/api/helix/summarize', body: {
        'subject': subject,
        'body': body,
        'from': from,
      });
      return response['summary'] as String?;
    } catch (e) {
      debugPrint('Error summarizing: $e');
      // Return a mock summary for demo
      return 'This email from $from discusses "$subject". It contains key points that may require your attention and follow-up action.';
    }
  }

  /// Generate an email draft
  Future<String?> generateDraft({
    required String context,
    Map<String, String>? replyTo,
  }) async {
    try {
      final response = await _backend.post('/api/helix/draft', body: {
        'context': context,
        if (replyTo != null) 'replyTo': replyTo,
      });
      return response['draft'] as String?;
    } catch (e) {
      debugPrint('Error generating draft: $e');
      return null;
    }
  }

  /// Generate smart reply suggestions
  Future<List<String>> generateSmartReplies({
    required String from,
    required String subject,
    required String body,
  }) async {
    try {
      final response = await _backend.post('/api/helix/smart-replies', body: {
        'from': from,
        'subject': subject,
        'body': body,
      });
      final replies = response['replies'] as List?;
      return replies?.map((r) => r.toString()).toList() ?? [];
    } catch (e) {
      debugPrint('Error generating smart replies: $e');
      // Return mock smart replies
      return [
        'Thanks for the update! I\'ll review and get back to you.',
        'Sounds good, let\'s discuss in our next meeting.',
        'Got it, I\'ll take a look at this today.',
      ];
    }
  }

  /// Generate inbox digest
  /// Generate inbox digest
  /// Body format matches backend: { emails: [{ from, subject, snippet, isRead }] }
  Future<String?> generateDigest({
    required int emailCount,
    required int unreadCount,
    List<Map<String, dynamic>>? emails,
  }) async {
    try {
      final response = await _backend.post('/api/helix/digest', body: {
        'emails': emails ?? [],
      });
      return response['digest'] as String?;
    } catch (e) {
      debugPrint('Error generating digest: $e');
      return 'You have $unreadCount unread emails out of $emailCount total. '
          'Focus on priority items first and review updates when you have time.';
    }
  }

  /// Chat with Helix AI
  /// Body format matches backend: { message, context? (string) }
  Future<String?> chat({
    required String message,
    String? context,
  }) async {
    try {
      final response = await _backend.post('/api/helix/chat', body: {
        'message': message,
        if (context != null) 'context': context,
      });
      return response['reply'] as String?;
    } catch (e) {
      debugPrint('Error in chat: $e');
      return 'I\'m having trouble connecting right now. Please try again in a moment.';
    }
  }

  /// Translate email body
  Future<String?> translateEmail({
    required String body,
    required String targetLanguage,
  }) async {
    try {
      final response = await _backend.post('/api/helix/translate', body: {
        'body': body,
        'language': targetLanguage,
      });
      return response['translation'] as String?;
    } catch (e) {
      debugPrint('Error translating: $e');
      return null;
    }
  }
}
