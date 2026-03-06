const express = require('express');
const { google } = require('googleapis');
const { requireAuth } = require('../middleware/auth');
const router = express.Router();

// All Calendar routes require authentication
router.use(requireAuth);

/**
 * GET /api/calendar/events
 * Fetch calendar events for a given date range.
 * Query params: timeMin, timeMax, maxResults (default 50), calendarId (default 'primary')
 */
router.get('/events', async (req, res) => {
  try {
    const calendar = google.calendar({ version: 'v3', auth: req.oauth2Client });

    const now = new Date();
    const {
      timeMin = now.toISOString(),
      timeMax = new Date(now.getTime() + 7 * 24 * 60 * 60 * 1000).toISOString(),
      maxResults = 50,
      calendarId = 'primary'
    } = req.query;

    const response = await calendar.events.list({
      calendarId,
      timeMin,
      timeMax,
      maxResults: parseInt(maxResults),
      singleEvents: true,
      orderBy: 'startTime'
    });

    const events = (response.data.items || []).map(parseCalendarEvent);

    res.json({
      events,
      summary: response.data.summary,
      timeZone: response.data.timeZone,
      nextPageToken: response.data.nextPageToken || null
    });
  } catch (error) {
    console.error('[Calendar List Error]', error.message);
    res.status(500).json({ error: 'Failed to fetch events', details: error.message });
  }
});

/**
 * GET /api/calendar/events/:id
 * Fetch a single event.
 */
router.get('/events/:id', async (req, res) => {
  try {
    const calendar = google.calendar({ version: 'v3', auth: req.oauth2Client });
    const { calendarId = 'primary' } = req.query;

    const response = await calendar.events.get({
      calendarId,
      eventId: req.params.id
    });

    res.json({ event: parseCalendarEvent(response.data) });
  } catch (error) {
    console.error('[Calendar Get Error]', error.message);
    res.status(500).json({ error: 'Failed to fetch event', details: error.message });
  }
});

/**
 * POST /api/calendar/events
 * Create a new event.
 * Body: { summary, description?, start, end, location?, attendees?, meetingLink? }
 */
router.post('/events', async (req, res) => {
  try {
    const calendar = google.calendar({ version: 'v3', auth: req.oauth2Client });
    const {
      summary,
      description,
      start,
      end,
      location,
      attendees,
      calendarId = 'primary',
      conferenceRequest
    } = req.body;

    if (!summary || !start || !end) {
      return res.status(400).json({ error: 'Missing required fields: summary, start, end' });
    }

    const eventBody = {
      summary,
      description: description || '',
      start: { dateTime: start, timeZone: 'America/New_York' },
      end: { dateTime: end, timeZone: 'America/New_York' },
      location: location || '',
      attendees: (attendees || []).map(email => ({ email }))
    };

    // Request a Google Meet link if specified
    if (conferenceRequest) {
      eventBody.conferenceData = {
        createRequest: {
          requestId: `voidmail-${Date.now()}`,
          conferenceSolutionKey: { type: 'hangoutsMeet' }
        }
      };
    }

    const response = await calendar.events.insert({
      calendarId,
      requestBody: eventBody,
      conferenceDataVersion: conferenceRequest ? 1 : 0
    });

    res.json({
      success: true,
      event: parseCalendarEvent(response.data)
    });
  } catch (error) {
    console.error('[Calendar Create Error]', error.message);
    res.status(500).json({ error: 'Failed to create event', details: error.message });
  }
});

/**
 * PUT /api/calendar/events/:id
 * Update an existing event.
 */
router.put('/events/:id', async (req, res) => {
  try {
    const calendar = google.calendar({ version: 'v3', auth: req.oauth2Client });
    const { calendarId = 'primary', ...eventData } = req.body;

    const eventBody = {};
    if (eventData.summary) eventBody.summary = eventData.summary;
    if (eventData.description) eventBody.description = eventData.description;
    if (eventData.start) eventBody.start = { dateTime: eventData.start };
    if (eventData.end) eventBody.end = { dateTime: eventData.end };
    if (eventData.location) eventBody.location = eventData.location;

    const response = await calendar.events.patch({
      calendarId,
      eventId: req.params.id,
      requestBody: eventBody
    });

    res.json({
      success: true,
      event: parseCalendarEvent(response.data)
    });
  } catch (error) {
    console.error('[Calendar Update Error]', error.message);
    res.status(500).json({ error: 'Failed to update event', details: error.message });
  }
});

/**
 * DELETE /api/calendar/events/:id
 * Delete a calendar event.
 */
router.delete('/events/:id', async (req, res) => {
  try {
    const calendar = google.calendar({ version: 'v3', auth: req.oauth2Client });
    const { calendarId = 'primary' } = req.query;

    await calendar.events.delete({
      calendarId,
      eventId: req.params.id
    });

    res.json({ success: true, deleted: true });
  } catch (error) {
    console.error('[Calendar Delete Error]', error.message);
    res.status(500).json({ error: 'Failed to delete event', details: error.message });
  }
});

/**
 * GET /api/calendar/calendars
 * List all calendars for the user.
 */
router.get('/calendars', async (req, res) => {
  try {
    const calendar = google.calendar({ version: 'v3', auth: req.oauth2Client });
    const response = await calendar.calendarList.list();

    const calendars = (response.data.items || []).map(cal => ({
      id: cal.id,
      summary: cal.summary,
      description: cal.description,
      primary: cal.primary || false,
      backgroundColor: cal.backgroundColor,
      foregroundColor: cal.foregroundColor,
      timeZone: cal.timeZone,
      accessRole: cal.accessRole
    }));

    res.json({ calendars });
  } catch (error) {
    console.error('[Calendar List Error]', error.message);
    res.status(500).json({ error: 'Failed to fetch calendars', details: error.message });
  }
});

/**
 * GET /api/calendar/today
 * Quick endpoint to get today's events.
 */
router.get('/today', async (req, res) => {
  try {
    const calendar = google.calendar({ version: 'v3', auth: req.oauth2Client });
    const now = new Date();
    const startOfDay = new Date(now.getFullYear(), now.getMonth(), now.getDate());
    const endOfDay = new Date(startOfDay.getTime() + 24 * 60 * 60 * 1000);

    const response = await calendar.events.list({
      calendarId: 'primary',
      timeMin: startOfDay.toISOString(),
      timeMax: endOfDay.toISOString(),
      singleEvents: true,
      orderBy: 'startTime'
    });

    const events = (response.data.items || []).map(parseCalendarEvent);

    res.json({
      date: startOfDay.toISOString().split('T')[0],
      events,
      count: events.length
    });
  } catch (error) {
    console.error('[Calendar Today Error]', error.message);
    res.status(500).json({ error: 'Failed to fetch today\'s events', details: error.message });
  }
});

// ─── Helpers ───────────────────────────────────────────

function parseCalendarEvent(event) {
  const start = event.start?.dateTime || event.start?.date || '';
  const end = event.end?.dateTime || event.end?.date || '';
  const isAllDay = !event.start?.dateTime;

  let meetingLink = null;
  if (event.conferenceData?.entryPoints) {
    const videoEntry = event.conferenceData.entryPoints.find(e => e.entryPointType === 'video');
    meetingLink = videoEntry?.uri || null;
  }
  if (!meetingLink && event.hangoutLink) {
    meetingLink = event.hangoutLink;
  }

  return {
    id: event.id,
    summary: event.summary || '(No Title)',
    description: event.description || '',
    start,
    end,
    isAllDay,
    location: event.location || '',
    meetingLink,
    status: event.status,
    organizer: event.organizer ? {
      email: event.organizer.email,
      displayName: event.organizer.displayName || event.organizer.email,
      self: event.organizer.self || false
    } : null,
    attendees: (event.attendees || []).map(a => ({
      email: a.email,
      displayName: a.displayName || a.email,
      responseStatus: a.responseStatus,
      self: a.self || false
    })),
    htmlLink: event.htmlLink,
    created: event.created,
    updated: event.updated
  };
}

module.exports = router;
