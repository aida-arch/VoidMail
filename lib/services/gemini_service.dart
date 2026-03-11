import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

/// AI Features via Gemini 2.0 Flash — direct API calls matching reference iOS app
class GeminiService {
  // Both loaded from .env at runtime
  String get _baseUrl => dotenv.env['GEMINI_BASE_URL'] ?? '';
  String get _apiKey => dotenv.env['GEMINI_API_KEY'] ?? '';

  /// Core Gemini API call
  Future<String?> _generateContent(
    String prompt, {
    int maxTokens = 500,
    double temperature = 0.7,
  }) async {
    if (_apiKey.isEmpty || _baseUrl.isEmpty) {
      debugPrint('[Gemini] API key or base URL not configured');
      return null;
    }

    try {
      final uri = Uri.parse('$_baseUrl?key=$_apiKey');
      final response = await http
          .post(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'contents': [
                {
                  'parts': [
                    {'text': prompt}
                  ]
                }
              ],
              'generationConfig': {
                'maxOutputTokens': maxTokens,
                'temperature': temperature,
                'topP': 0.95,
              },
            }),
          )
          .timeout(const Duration(seconds: 30));

      if (response.statusCode != 200) {
        debugPrint('[Gemini] API error ${response.statusCode}: ${response.body}');
        return null;
      }

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final candidates = json['candidates'] as List?;
      if (candidates == null || candidates.isEmpty) return null;

      final content = candidates[0]['content'] as Map<String, dynamic>?;
      final parts = content?['parts'] as List?;
      final text = parts?.first['text'] as String?;

      return text?.trim();
    } catch (e) {
      debugPrint('[Gemini] Error: $e');
      return null;
    }
  }

  /// Summarize an email in 1-2 sentences
  Future<String?> summarizeEmail({
    required String subject,
    required String body,
    required String from,
  }) async {
    final result = await _generateContent(
      'You are Helix-o1, an AI email assistant. Summarize this email in 1-2 concise sentences. '
      'Focus on action items and key information. Be direct and brief.\n\n'
      'From: $from\nSubject: $subject\nBody:\n${body.length > 2000 ? body.substring(0, 2000) : body}\n\nSummary:',
      maxTokens: 150,
      temperature: 0.3,
    );
    return result ??
        'This email from $from discusses "$subject". It contains key points that may require your attention.';
  }

  /// Generate an email draft
  Future<String?> generateDraft({
    required String context,
    Map<String, String>? replyTo,
  }) async {
    String prompt;
    if (replyTo != null) {
      prompt = 'Write a professional, concise email reply. Keep it natural and brief (3-5 sentences).\n\n'
          'Original email from ${replyTo['from'] ?? 'someone'}:\n'
          'Subject: ${replyTo['subject'] ?? ''}\n'
          '${(replyTo['body'] ?? '').length > 1500 ? replyTo['body']!.substring(0, 1500) : replyTo['body'] ?? ''}\n\n'
          '${context.isEmpty ? 'Write a thoughtful reply.' : 'Additional context: $context'}\n\n'
          'Write only the email body text. No subject line.\nReply:';
    } else {
      prompt = 'Write a professional, concise email.\n\n'
          'Topic/Context: ${context.isEmpty ? 'General professional email' : context}\n\n'
          'Write only the email body text.\nEmail:';
    }
    return await _generateContent(prompt, maxTokens: 400, temperature: 0.7);
  }

  /// Generate smart reply suggestions
  Future<List<String>> generateSmartReplies({
    required String from,
    required String subject,
    required String body,
  }) async {
    final result = await _generateContent(
      'Given this email, suggest exactly 3 short reply options (1 sentence each, max 15 words).\n'
      'Format each on a new line, numbered 1. 2. 3.\n\n'
      'From: $from\nSubject: $subject\n${body.length > 1000 ? body.substring(0, 1000) : body}\n\nReplies:',
      maxTokens: 150,
      temperature: 0.8,
    );
    if (result == null) {
      return ['Thanks!', 'Got it, will review.', 'Let me get back to you.'];
    }
    final replies = result
        .split('\n')
        .map((l) => l.replaceFirst(RegExp(r'^\d+[\.\)]\s*'), '').trim())
        .where((l) => l.isNotEmpty && l.length < 100)
        .take(3)
        .toList();
    return replies.isNotEmpty
        ? replies
        : ['Thanks!', 'Got it, will review.', 'Let me get back to you.'];
  }

  /// Generate inbox digest
  Future<String?> generateDigest({
    required int emailCount,
    required int unreadCount,
    List<Map<String, dynamic>>? emails,
  }) async {
    if (emails == null || emails.isEmpty) {
      return 'No recent emails to summarize.';
    }
    final emailList = emails.take(10).toList().asMap().entries.map((e) {
      final i = e.key + 1;
      final em = e.value;
      return '$i. From ${em['from']}: "${em['subject']}" — ${em['snippet'] ?? ''}${em['isRead'] == true ? '' : ' [UNREAD]'}';
    }).join('\n');

    final result = await _generateContent(
      'You are an AI email assistant. Write a brief inbox digest (3-4 sentences) for today.\n'
      'Highlight what needs attention, important action items, and any urgent messages.\n'
      'There are $unreadCount unread emails out of $emailCount total.\n\n'
      'Recent emails:\n$emailList\n\nToday\'s digest:',
      maxTokens: 200,
      temperature: 0.5,
    );
    return result ??
        'You have $unreadCount unread emails out of $emailCount total. '
            'Focus on priority items first and review updates when you have time.';
  }

  /// Chat with Helix AI
  Future<String?> chat({
    required String message,
    String? context,
  }) async {
    final result = await _generateContent(
      'You are Helix-o1, an AI email and productivity assistant built into VoidMail. '
      'You help users manage their inbox, draft emails, understand email content, and stay productive. Be concise and helpful.\n\n'
      '${context != null ? 'Context:\n$context\n\n' : ''}'
      'User: $message\n\nHelix-o1:',
      maxTokens: 500,
      temperature: 0.7,
    );
    return result ?? 'I\'m having trouble connecting right now. Please try again in a moment.';
  }

  /// Translate email body
  Future<String?> translateEmail({
    required String body,
    required String targetLanguage,
  }) async {
    if (body.trim().isEmpty) {
      debugPrint('[Gemini] translateEmail: empty body, skipping');
      return null;
    }
    final result = await _generateContent(
      'Translate the following email body to $targetLanguage. Keep the formatting and tone. '
      'Only output the translated text, no explanations.\n\n'
      'Email:\n${body.length > 3000 ? body.substring(0, 3000) : body}\n\nTranslation:',
      maxTokens: 2000,
      temperature: 0.3,
    );
    if (result == null) {
      debugPrint('[Gemini] translateEmail: API returned null for language=$targetLanguage');
    }
    return result;
  }

  /// Generate an email subject from the body content
  Future<String?> generateEmailSubject({required String body}) async {
    final result = await _generateContent(
      'Generate a concise, professional email subject line for the following email body. '
      'Reply with ONLY the subject line, nothing else. Max 10 words.\n\n'
      'Email body:\n${body.length > 1500 ? body.substring(0, 1500) : body}\n\nSubject:',
      maxTokens: 30,
      temperature: 0.5,
    );
    return result
        ?.replaceAll('"', '')
        .replaceAll("'", '')
        .replaceAll('Subject: ', '')
        .trim();
  }

  /// Check if an email is high priority
  Future<bool> isEmailPriority({
    required String subject,
    required String body,
    required String from,
  }) async {
    final result = await _generateContent(
      'Is this email high priority or urgent? Reply with ONLY "yes" or "no".\n'
      'Consider: deadlines, action required, important decisions, urgent requests.\n\n'
      'From: $from\nSubject: $subject\n'
      'Preview: ${body.length > 300 ? body.substring(0, 300) : body}\n\nPriority:',
      maxTokens: 10,
      temperature: 0.1,
    );
    return result?.toLowerCase().contains('yes') ?? false;
  }

  /// Check Helix AI service status
  Future<bool> checkHelixStatus() async {
    final result = await _generateContent(
      'Say "Helix-o1 online" in exactly those words.',
      maxTokens: 10,
      temperature: 0,
    );
    return result != null;
  }
}
