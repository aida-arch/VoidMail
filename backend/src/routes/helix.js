const express = require('express');
const fetch = require('node-fetch');
const { optionalAuth } = require('../middleware/auth');
const router = express.Router();

const GEMINI_API_KEY = process.env.GEMINI_API_KEY;
const GEMINI_ENDPOINT = 'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent';

/**
 * Core Gemini API call
 */
async function callGemini(prompt, maxTokens = 256, temperature = 0.7) {
  const url = `${GEMINI_ENDPOINT}?key=${GEMINI_API_KEY}`;

  const response = await fetch(url, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      contents: [{ parts: [{ text: prompt }] }],
      generationConfig: {
        maxOutputTokens: maxTokens,
        temperature
      }
    })
  });

  if (!response.ok) {
    const errorData = await response.json().catch(() => ({}));
    throw new Error(`Gemini API error ${response.status}: ${errorData.error?.message || 'Unknown error'}`);
  }

  const data = await response.json();
  const text = data.candidates?.[0]?.content?.parts?.[0]?.text;

  if (!text) {
    throw new Error('No content in Gemini response');
  }

  return text.trim();
}

/**
 * POST /api/helix/summarize
 * Summarize an email.
 * Body: { subject, body, from }
 */
router.post('/summarize', async (req, res) => {
  try {
    const { subject, body, from } = req.body;

    if (!subject && !body) {
      return res.status(400).json({ error: 'Missing subject or body' });
    }

    const prompt = `You are Helix-o1, an AI email assistant. Summarize this email in 1-2 concise sentences. Focus on the key action or information.

From: ${from || 'Unknown'}
Subject: ${subject || '(no subject)'}

${(body || '').substring(0, 2000)}

Summary:`;

    const summary = await callGemini(prompt, 150, 0.3);
    res.json({ summary });
  } catch (error) {
    console.error('[Helix Summarize Error]', error.message);
    res.status(500).json({ error: 'Failed to generate summary', details: error.message });
  }
});

/**
 * POST /api/helix/draft
 * Generate an AI email draft.
 * Body: { context, replyTo? { from, subject, body } }
 */
router.post('/draft', async (req, res) => {
  try {
    const { context, replyTo } = req.body;

    let prompt;
    if (replyTo) {
      prompt = `You are Helix-o1, an AI email assistant. Draft a professional reply to this email.

Original email from ${replyTo.from || 'someone'}:
Subject: ${replyTo.subject || ''}
Body: ${(replyTo.body || '').substring(0, 1500)}

${context ? `User's instructions: ${context}` : ''}

Write a concise, professional reply. Don't include the subject line, just the body text:`;
    } else {
      prompt = `You are Helix-o1, an AI email assistant. Draft a professional email based on these instructions:

${context || 'Write a general professional email.'}

Write a concise, professional email body. Don't include the subject line:`;
    }

    const draft = await callGemini(prompt, 400, 0.7);
    res.json({ draft });
  } catch (error) {
    console.error('[Helix Draft Error]', error.message);
    res.status(500).json({ error: 'Failed to generate draft', details: error.message });
  }
});

/**
 * POST /api/helix/smart-replies
 * Generate quick reply suggestions.
 * Body: { from, subject, body }
 */
router.post('/smart-replies', async (req, res) => {
  try {
    const { from, subject, body } = req.body;

    const prompt = `You are Helix-o1, an AI email assistant. Generate exactly 3 short, natural reply suggestions for this email. Each reply should be a brief phrase (3-8 words) that could start a response.

From: ${from || 'Unknown'}
Subject: ${subject || '(no subject)'}
Body: ${(body || '').substring(0, 1000)}

Reply in this exact format (one per line):
1. [reply]
2. [reply]
3. [reply]`;

    const result = await callGemini(prompt, 150, 0.8);
    const replies = result
      .split('\n')
      .map(line => line.replace(/^\d+\.\s*/, '').trim())
      .filter(line => line.length > 0 && line.length < 100)
      .slice(0, 3);

    res.json({ replies: replies.length > 0 ? replies : ['Thanks!', 'Got it, will review.', 'Let me get back to you.'] });
  } catch (error) {
    console.error('[Helix Smart Replies Error]', error.message);
    res.json({ replies: ['Thanks!', 'Got it, will review.', 'Let me get back to you.'] });
  }
});

/**
 * POST /api/helix/digest
 * Generate an inbox digest from recent emails.
 * Body: { emails: [{ from, subject, snippet, isRead }] }
 */
router.post('/digest', async (req, res) => {
  try {
    const { emails } = req.body;

    if (!emails || emails.length === 0) {
      return res.json({ digest: 'No recent emails to summarize.' });
    }

    const emailList = emails.slice(0, 10).map((e, i) =>
      `${i + 1}. From: ${e.from} | Subject: ${e.subject} | ${e.isRead ? 'Read' : 'Unread'} | ${e.snippet || ''}`
    ).join('\n');

    const prompt = `You are Helix-o1, an AI email assistant. Provide a brief inbox digest (2-3 sentences) summarizing the user's recent emails. Highlight any urgent or important items.

Recent emails:
${emailList}

Digest:`;

    const digest = await callGemini(prompt, 200, 0.5);
    res.json({ digest });
  } catch (error) {
    console.error('[Helix Digest Error]', error.message);
    res.status(500).json({ error: 'Failed to generate digest', details: error.message });
  }
});

/**
 * POST /api/helix/categorize
 * Categorize an email.
 * Body: { subject, from, snippet }
 */
router.post('/categorize', async (req, res) => {
  try {
    const { subject, from, snippet } = req.body;

    const prompt = `Categorize this email into exactly one category. Reply with ONLY the category name.

Categories: primary, updates, promotions, social, forums, newsletters

From: ${from || 'Unknown'}
Subject: ${subject || '(no subject)'}
Preview: ${(snippet || '').substring(0, 300)}

Category:`;

    const category = await callGemini(prompt, 20, 0.2);
    const normalized = category.toLowerCase().trim().replace(/[^a-z]/g, '');
    const validCategories = ['primary', 'updates', 'promotions', 'social', 'forums', 'newsletters'];
    const finalCategory = validCategories.includes(normalized) ? normalized : 'primary';

    res.json({ category: finalCategory });
  } catch (error) {
    console.error('[Helix Categorize Error]', error.message);
    res.json({ category: 'primary' });
  }
});

/**
 * POST /api/helix/chat
 * Free-form chat with Helix-o1 about email context.
 * Body: { message, context? }
 */
router.post('/chat', async (req, res) => {
  try {
    const { message, context } = req.body;

    if (!message) {
      return res.status(400).json({ error: 'Missing message' });
    }

    const prompt = `You are Helix-o1, an AI email and productivity assistant built into VoidMail. You help users manage their inbox, draft emails, understand email content, and stay productive. Be concise and helpful.

${context ? `Context:\n${context}\n\n` : ''}User: ${message}

Helix-o1:`;

    const reply = await callGemini(prompt, 500, 0.7);
    res.json({ reply });
  } catch (error) {
    console.error('[Helix Chat Error]', error.message);
    res.status(500).json({ error: 'Failed to process chat', details: error.message });
  }
});

/**
 * GET /api/helix/status
 * Health check for the Helix-o1 AI service.
 */
router.get('/status', async (req, res) => {
  try {
    const testResult = await callGemini('Say "Helix-o1 online" in exactly those words.', 10, 0);
    res.json({
      status: 'online',
      model: 'gemini-2.0-flash',
      name: 'Helix-o1',
      response: testResult
    });
  } catch (error) {
    res.json({
      status: 'error',
      model: 'gemini-2.0-flash',
      name: 'Helix-o1',
      error: error.message
    });
  }
});

module.exports = router;
