const express = require('express');
const fetch = require('node-fetch');
const { optionalAuth } = require('../middleware/auth');
const router = express.Router();

const GEMINI_API_KEY = process.env.GEMINI_API_KEY;
const GEMINI_ENDPOINT = 'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent';

async function callGemini(prompt, maxTokens = 256, temperature = 0.7) {
  const url = `${GEMINI_ENDPOINT}?key=${GEMINI_API_KEY}`;

  const response = await fetch(url, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      contents: [{ parts: [{ text: prompt }] }],
      generationConfig: { maxOutputTokens: maxTokens, temperature }
    })
  });

  if (!response.ok) {
    const errorData = await response.json().catch(() => ({}));
    throw new Error(`Gemini API error ${response.status}: ${errorData.error?.message || 'Unknown error'}`);
  }

  const data = await response.json();
  const text = data.candidates?.[0]?.content?.parts?.[0]?.text;
  if (!text) throw new Error('No content in Gemini response');
  return text.trim();
}

router.post('/summarize', async (req, res) => {
  try {
    const { subject, body, from } = req.body;
    if (!subject && !body) return res.status(400).json({ error: 'Missing subject or body' });

    const prompt = `You are Helix-o1, an AI email assistant. Summarize this email in 1-2 concise sentences. Focus on the key action or information.\n\nFrom: ${from || 'Unknown'}\nSubject: ${subject || '(no subject)'}\n\n${(body || '').substring(0, 2000)}\n\nSummary:`;
    const summary = await callGemini(prompt, 150, 0.3);
    res.json({ summary });
  } catch (error) {
    console.error('[Helix Summarize Error]', error.message);
    res.status(500).json({ error: 'Failed to generate summary', details: error.message });
  }
});

router.post('/draft', async (req, res) => {
  try {
    const { context, replyTo } = req.body;
    let prompt;
    if (replyTo) {
      prompt = `You are Helix-o1, an AI email assistant. Draft a professional reply to this email.\n\nOriginal email from ${replyTo.from || 'someone'}:\nSubject: ${replyTo.subject || ''}\nBody: ${(replyTo.body || '').substring(0, 1500)}\n\n${context ? `User's instructions: ${context}` : ''}\n\nWrite a concise, professional reply. Don't include the subject line, just the body text:`;
    } else {
      prompt = `You are Helix-o1, an AI email assistant. Draft a professional email based on these instructions:\n\n${context || 'Write a general professional email.'}\n\nWrite a concise, professional email body. Don't include the subject line:`;
    }
    const draft = await callGemini(prompt, 400, 0.7);
    res.json({ draft });
  } catch (error) {
    console.error('[Helix Draft Error]', error.message);
    res.status(500).json({ error: 'Failed to generate draft', details: error.message });
  }
});

router.post('/smart-replies', async (req, res) => {
  try {
    const { from, subject, body } = req.body;
    const prompt = `You are Helix-o1, an AI email assistant. Generate exactly 3 short, natural reply suggestions for this email. Each reply should be a brief phrase (3-8 words) that could start a response.\n\nFrom: ${from || 'Unknown'}\nSubject: ${subject || '(no subject)'}\nBody: ${(body || '').substring(0, 1000)}\n\nReply in this exact format (one per line):\n1. [reply]\n2. [reply]\n3. [reply]`;

    const result = await callGemini(prompt, 150, 0.8);
    const replies = result.split('\n').map(line => line.replace(/^\d+\.\s*/, '').trim()).filter(line => line.length > 0 && line.length < 100).slice(0, 3);
    res.json({ replies: replies.length > 0 ? replies : ['Thanks!', 'Got it, will review.', 'Let me get back to you.'] });
  } catch (error) {
    console.error('[Helix Smart Replies Error]', error.message);
    res.json({ replies: ['Thanks!', 'Got it, will review.', 'Let me get back to you.'] });
  }
});

router.post('/digest', async (req, res) => {
  try {
    const { emails } = req.body;
    if (!emails || emails.length === 0) return res.json({ digest: 'No recent emails to summarize.' });

    const emailList = emails.slice(0, 10).map((e, i) =>
      `${i + 1}. From: ${e.from} | Subject: ${e.subject} | ${e.isRead ? 'Read' : 'Unread'} | ${e.snippet || ''}`
    ).join('\n');

    const prompt = `You are Helix-o1, an AI email assistant. Provide a brief inbox digest (2-3 sentences) summarizing the user's recent emails. Highlight any urgent or important items.\n\nRecent emails:\n${emailList}\n\nDigest:`;
    const digest = await callGemini(prompt, 200, 0.5);
    res.json({ digest });
  } catch (error) {
    console.error('[Helix Digest Error]', error.message);
    res.status(500).json({ error: 'Failed to generate digest', details: error.message });
  }
});

router.post('/categorize', async (req, res) => {
  try {
    const { subject, from, snippet } = req.body;
    const prompt = `Categorize this email into exactly one category. Reply with ONLY the category name.\n\nCategories: primary, updates, promotions, social, forums, newsletters\n\nFrom: ${from || 'Unknown'}\nSubject: ${subject || '(no subject)'}\nPreview: ${(snippet || '').substring(0, 300)}\n\nCategory:`;

    const category = await callGemini(prompt, 20, 0.2);
    const normalized = category.toLowerCase().trim().replace(/[^a-z]/g, '');
    const validCategories = ['primary', 'updates', 'promotions', 'social', 'forums', 'newsletters'];
    res.json({ category: validCategories.includes(normalized) ? normalized : 'primary' });
  } catch (error) {
    console.error('[Helix Categorize Error]', error.message);
    res.json({ category: 'primary' });
  }
});

router.post('/chat', async (req, res) => {
  try {
    const { message, context } = req.body;
    if (!message) return res.status(400).json({ error: 'Missing message' });

    const prompt = `You are Helix-o1, an AI email and productivity assistant built into VoidMail. You help users manage their inbox, draft emails, understand email content, and stay productive. Be concise and helpful.\n\n${context ? `Context:\n${context}\n\n` : ''}User: ${message}\n\nHelix-o1:`;
    const reply = await callGemini(prompt, 500, 0.7);
    res.json({ reply });
  } catch (error) {
    console.error('[Helix Chat Error]', error.message);
    res.status(500).json({ error: 'Failed to process chat', details: error.message });
  }
});

router.get('/status', async (req, res) => {
  try {
    const testResult = await callGemini('Say "Helix-o1 online" in exactly those words.', 10, 0);
    res.json({ status: 'online', model: 'gemini-2.0-flash', name: 'Helix-o1', response: testResult });
  } catch (error) {
    res.json({ status: 'error', model: 'gemini-2.0-flash', name: 'Helix-o1', error: error.message });
  }
});

module.exports = router;
