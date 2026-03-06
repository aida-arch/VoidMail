const express = require('express');
const { google } = require('googleapis');
const { requireAuth } = require('../middleware/auth');
const router = express.Router();

// All Gmail routes require authentication
router.use(requireAuth);

/**
 * GET /api/gmail/messages
 * Fetch inbox messages with optional query filter.
 * Query params: q (search query), maxResults (default 20), pageToken
 */
router.get('/messages', async (req, res) => {
  try {
    const gmail = google.gmail({ version: 'v1', auth: req.oauth2Client });
    const { q, maxResults = 20, pageToken } = req.query;

    // List message IDs
    const listResponse = await gmail.users.messages.list({
      userId: 'me',
      q: q || 'in:inbox',
      maxResults: parseInt(maxResults),
      pageToken: pageToken || undefined
    });

    if (!listResponse.data.messages || listResponse.data.messages.length === 0) {
      return res.json({ messages: [], nextPageToken: null, resultSizeEstimate: 0 });
    }

    // Fetch full message details in parallel
    const messagePromises = listResponse.data.messages.map(msg =>
      gmail.users.messages.get({
        userId: 'me',
        id: msg.id,
        format: 'full'
      })
    );

    const messageResponses = await Promise.all(messagePromises);
    const messages = messageResponses.map(response => parseGmailMessage(response.data));

    res.json({
      messages,
      nextPageToken: listResponse.data.nextPageToken || null,
      resultSizeEstimate: listResponse.data.resultSizeEstimate || 0
    });
  } catch (error) {
    console.error('[Gmail List Error]', error.message);
    res.status(500).json({ error: 'Failed to fetch messages', details: error.message });
  }
});

/**
 * GET /api/gmail/messages/:id
 * Fetch a single message by ID.
 */
router.get('/messages/:id', async (req, res) => {
  try {
    const gmail = google.gmail({ version: 'v1', auth: req.oauth2Client });
    const response = await gmail.users.messages.get({
      userId: 'me',
      id: req.params.id,
      format: 'full'
    });

    res.json({ message: parseGmailMessage(response.data) });
  } catch (error) {
    console.error('[Gmail Get Error]', error.message);
    res.status(500).json({ error: 'Failed to fetch message', details: error.message });
  }
});

/**
 * POST /api/gmail/messages/send
 * Send an email.
 * Body: { to, subject, body, replyToMessageId?, threadId? }
 */
router.post('/messages/send', async (req, res) => {
  try {
    const gmail = google.gmail({ version: 'v1', auth: req.oauth2Client });
    const { to, subject, body, replyToMessageId, threadId } = req.body;

    if (!to || !subject || !body) {
      return res.status(400).json({ error: 'Missing required fields: to, subject, body' });
    }

    // Build MIME message
    const headers = [
      `To: ${to}`,
      `Subject: ${subject}`,
      'Content-Type: text/plain; charset=utf-8',
      'MIME-Version: 1.0'
    ];

    if (replyToMessageId) {
      headers.push(`In-Reply-To: ${replyToMessageId}`);
      headers.push(`References: ${replyToMessageId}`);
    }

    const rawMessage = headers.join('\r\n') + '\r\n\r\n' + body;
    const encodedMessage = Buffer.from(rawMessage)
      .toString('base64')
      .replace(/\+/g, '-')
      .replace(/\//g, '_')
      .replace(/=+$/, '');

    const sendPayload = { raw: encodedMessage };
    if (threadId) {
      sendPayload.threadId = threadId;
    }

    const response = await gmail.users.messages.send({
      userId: 'me',
      requestBody: sendPayload
    });

    res.json({
      success: true,
      messageId: response.data.id,
      threadId: response.data.threadId
    });
  } catch (error) {
    console.error('[Gmail Send Error]', error.message);
    res.status(500).json({ error: 'Failed to send message', details: error.message });
  }
});

/**
 * POST /api/gmail/messages/:id/modify
 * Modify message labels (star, read, archive, etc).
 * Body: { addLabelIds?, removeLabelIds? }
 */
router.post('/messages/:id/modify', async (req, res) => {
  try {
    const gmail = google.gmail({ version: 'v1', auth: req.oauth2Client });
    const { addLabelIds, removeLabelIds } = req.body;

    const response = await gmail.users.messages.modify({
      userId: 'me',
      id: req.params.id,
      requestBody: {
        addLabelIds: addLabelIds || [],
        removeLabelIds: removeLabelIds || []
      }
    });

    res.json({ success: true, labelIds: response.data.labelIds });
  } catch (error) {
    console.error('[Gmail Modify Error]', error.message);
    res.status(500).json({ error: 'Failed to modify message', details: error.message });
  }
});

/**
 * POST /api/gmail/messages/:id/star
 * Toggle star on a message.
 */
router.post('/messages/:id/star', async (req, res) => {
  try {
    const gmail = google.gmail({ version: 'v1', auth: req.oauth2Client });
    const { starred } = req.body;

    const response = await gmail.users.messages.modify({
      userId: 'me',
      id: req.params.id,
      requestBody: starred
        ? { addLabelIds: ['STARRED'] }
        : { removeLabelIds: ['STARRED'] }
    });

    res.json({ success: true, starred, labelIds: response.data.labelIds });
  } catch (error) {
    console.error('[Gmail Star Error]', error.message);
    res.status(500).json({ error: 'Failed to toggle star', details: error.message });
  }
});

/**
 * POST /api/gmail/messages/:id/read
 * Mark message as read or unread.
 */
router.post('/messages/:id/read', async (req, res) => {
  try {
    const gmail = google.gmail({ version: 'v1', auth: req.oauth2Client });
    const { read } = req.body;

    const response = await gmail.users.messages.modify({
      userId: 'me',
      id: req.params.id,
      requestBody: read
        ? { removeLabelIds: ['UNREAD'] }
        : { addLabelIds: ['UNREAD'] }
    });

    res.json({ success: true, read, labelIds: response.data.labelIds });
  } catch (error) {
    console.error('[Gmail Read Error]', error.message);
    res.status(500).json({ error: 'Failed to toggle read status', details: error.message });
  }
});

/**
 * POST /api/gmail/messages/:id/archive
 * Archive a message (remove from INBOX).
 */
router.post('/messages/:id/archive', async (req, res) => {
  try {
    const gmail = google.gmail({ version: 'v1', auth: req.oauth2Client });

    await gmail.users.messages.modify({
      userId: 'me',
      id: req.params.id,
      requestBody: { removeLabelIds: ['INBOX'] }
    });

    res.json({ success: true, archived: true });
  } catch (error) {
    console.error('[Gmail Archive Error]', error.message);
    res.status(500).json({ error: 'Failed to archive message', details: error.message });
  }
});

/**
 * DELETE /api/gmail/messages/:id
 * Trash a message.
 */
router.delete('/messages/:id', async (req, res) => {
  try {
    const gmail = google.gmail({ version: 'v1', auth: req.oauth2Client });

    await gmail.users.messages.trash({
      userId: 'me',
      id: req.params.id
    });

    res.json({ success: true, trashed: true });
  } catch (error) {
    console.error('[Gmail Delete Error]', error.message);
    res.status(500).json({ error: 'Failed to trash message', details: error.message });
  }
});

/**
 * GET /api/gmail/labels
 * List all Gmail labels.
 */
router.get('/labels', async (req, res) => {
  try {
    const gmail = google.gmail({ version: 'v1', auth: req.oauth2Client });
    const response = await gmail.users.labels.list({ userId: 'me' });

    res.json({ labels: response.data.labels || [] });
  } catch (error) {
    console.error('[Gmail Labels Error]', error.message);
    res.status(500).json({ error: 'Failed to fetch labels', details: error.message });
  }
});

/**
 * GET /api/gmail/profile
 * Get Gmail profile (email, messages total, threads total).
 */
router.get('/profile', async (req, res) => {
  try {
    const gmail = google.gmail({ version: 'v1', auth: req.oauth2Client });
    const response = await gmail.users.getProfile({ userId: 'me' });

    res.json({
      email: response.data.emailAddress,
      messagesTotal: response.data.messagesTotal,
      threadsTotal: response.data.threadsTotal,
      historyId: response.data.historyId
    });
  } catch (error) {
    console.error('[Gmail Profile Error]', error.message);
    res.status(500).json({ error: 'Failed to fetch profile', details: error.message });
  }
});

// ─── Helpers ───────────────────────────────────────────

function parseGmailMessage(msg) {
  const headers = msg.payload?.headers || [];
  const getHeader = (name) => headers.find(h => h.name.toLowerCase() === name.toLowerCase())?.value || '';

  const from = parseContact(getHeader('From'));
  const to = (getHeader('To') || '').split(',').map(t => parseContact(t.trim())).filter(c => c.email);
  const cc = (getHeader('Cc') || '').split(',').map(t => parseContact(t.trim())).filter(c => c.email);

  const labels = msg.labelIds || [];
  const body = extractBody(msg.payload);
  const attachments = extractAttachments(msg.payload);

  return {
    id: msg.id,
    threadId: msg.threadId,
    subject: getHeader('Subject') || '(no subject)',
    from,
    to,
    cc,
    date: getHeader('Date'),
    snippet: msg.snippet || '',
    body,
    isRead: !labels.includes('UNREAD'),
    isStarred: labels.includes('STARRED'),
    labels,
    attachments,
    internalDate: msg.internalDate
  };
}

function extractBody(payload) {
  if (!payload) return '';

  // Direct body
  if (payload.body?.data) {
    return Buffer.from(payload.body.data, 'base64').toString('utf-8');
  }

  // Multipart — look for text/plain then text/html
  if (payload.parts) {
    const textPart = payload.parts.find(p => p.mimeType === 'text/plain');
    if (textPart?.body?.data) {
      return Buffer.from(textPart.body.data, 'base64').toString('utf-8');
    }

    const htmlPart = payload.parts.find(p => p.mimeType === 'text/html');
    if (htmlPart?.body?.data) {
      const html = Buffer.from(htmlPart.body.data, 'base64').toString('utf-8');
      // Strip HTML tags for plain text
      return html.replace(/<[^>]*>/g, '').replace(/&nbsp;/g, ' ').replace(/\s+/g, ' ').trim();
    }

    // Nested multipart
    for (const part of payload.parts) {
      if (part.parts) {
        const nested = extractBody(part);
        if (nested) return nested;
      }
    }
  }

  return '';
}

function extractAttachments(payload) {
  const attachments = [];

  function walkParts(parts) {
    if (!parts) return;
    for (const part of parts) {
      if (part.filename && part.filename.length > 0) {
        attachments.push({
          id: part.body?.attachmentId || '',
          name: part.filename,
          mimeType: part.mimeType,
          size: part.body?.size || 0
        });
      }
      if (part.parts) {
        walkParts(part.parts);
      }
    }
  }

  if (payload.parts) {
    walkParts(payload.parts);
  }

  return attachments;
}

function parseContact(raw) {
  if (!raw) return { displayName: '', email: '' };
  const match = raw.match(/^"?(.+?)"?\s*<(.+?)>$/);
  if (match) {
    return { displayName: match[1].trim(), email: match[2].trim() };
  }
  return { displayName: raw.trim(), email: raw.trim() };
}

module.exports = router;
