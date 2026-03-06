const express = require('express');
const { google } = require('googleapis');
const router = express.Router();

function createOAuth2Client(redirectUri) {
  return new google.auth.OAuth2(
    process.env.GOOGLE_CLIENT_ID,
    process.env.GOOGLE_CLIENT_SECRET,
    redirectUri || process.env.GOOGLE_REDIRECT_URI
  );
}

const SCOPES = [
  'https://www.googleapis.com/auth/gmail.modify',
  'https://www.googleapis.com/auth/gmail.send',
  'https://www.googleapis.com/auth/gmail.readonly',
  'https://www.googleapis.com/auth/calendar',
  'https://www.googleapis.com/auth/calendar.events',
  'https://www.googleapis.com/auth/userinfo.email',
  'https://www.googleapis.com/auth/userinfo.profile'
];

/**
 * GET /auth/google
 * Returns the Google OAuth consent URL for the iOS app to open.
 */
router.get('/google', (req, res) => {
  const redirectUri = req.query.redirect_uri || process.env.GOOGLE_REDIRECT_URI;
  const oauth2Client = createOAuth2Client(redirectUri);

  const authUrl = oauth2Client.generateAuthUrl({
    access_type: 'offline',
    scope: SCOPES,
    prompt: 'consent',
    include_granted_scopes: true
  });

  res.json({ authUrl, scopes: SCOPES });
});

/**
 * GET /auth/google/callback
 * Handles the OAuth callback — exchanges code for tokens,
 * then redirects to the iOS app's custom URL scheme with the data.
 */
router.get('/google/callback', async (req, res) => {
  const { code, error: oauthError } = req.query;

  // iOS custom URL scheme for redirect
  const iosScheme = 'com.googleusercontent.apps.' + process.env.GOOGLE_CLIENT_ID.split('.')[0];

  if (oauthError) {
    const errorRedirect = `${iosScheme}:/oauth2callback?error=${encodeURIComponent(oauthError)}`;
    return res.redirect(errorRedirect);
  }

  if (!code) {
    const errorRedirect = `${iosScheme}:/oauth2callback?error=missing_code`;
    return res.redirect(errorRedirect);
  }

  try {
    const oauth2Client = createOAuth2Client();
    const { tokens } = await oauth2Client.getToken(code);
    oauth2Client.setCredentials(tokens);

    // Get user profile
    const oauth2 = google.oauth2({ version: 'v2', auth: oauth2Client });
    const { data: userInfo } = await oauth2.userinfo.get();

    // Build redirect URL with all data as query params
    const params = new URLSearchParams({
      access_token: tokens.access_token || '',
      refresh_token: tokens.refresh_token || '',
      expiry_date: String(tokens.expiry_date || ''),
      user_id: userInfo.id || '',
      user_email: userInfo.email || '',
      user_name: userInfo.name || '',
      user_picture: userInfo.picture || ''
    });

    const redirectURL = `${iosScheme}:/oauth2callback?${params.toString()}`;
    console.log(`[Auth Callback] Redirecting to iOS app for ${userInfo.email}`);
    res.redirect(redirectURL);
  } catch (error) {
    console.error('[Auth Callback Error]', error.message);
    const errorRedirect = `${iosScheme}:/oauth2callback?error=${encodeURIComponent(error.message)}`;
    res.redirect(errorRedirect);
  }
});

/**
 * POST /auth/google/token
 * Exchange authorization code for tokens (for iOS app flow).
 * Body: { code, redirect_uri }
 */
router.post('/google/token', async (req, res) => {
  const { code, redirect_uri } = req.body;

  if (!code) {
    return res.status(400).json({ error: 'Missing authorization code' });
  }

  try {
    const oauth2Client = createOAuth2Client(redirect_uri);
    const { tokens } = await oauth2Client.getToken(code);
    oauth2Client.setCredentials(tokens);

    // Get user profile
    const oauth2 = google.oauth2({ version: 'v2', auth: oauth2Client });
    const { data: userInfo } = await oauth2.userinfo.get();

    res.json({
      user: {
        id: userInfo.id,
        email: userInfo.email,
        name: userInfo.name,
        picture: userInfo.picture
      },
      tokens: {
        access_token: tokens.access_token,
        refresh_token: tokens.refresh_token,
        expiry_date: tokens.expiry_date,
        token_type: tokens.token_type,
        scope: tokens.scope
      }
    });
  } catch (error) {
    console.error('[Token Exchange Error]', error.message);
    res.status(500).json({ error: 'Failed to exchange authorization code', details: error.message });
  }
});

/**
 * POST /auth/google/refresh
 * Refresh an expired access token.
 * Body: { refresh_token }
 */
router.post('/google/refresh', async (req, res) => {
  const { refresh_token } = req.body;

  if (!refresh_token) {
    return res.status(400).json({ error: 'Missing refresh_token' });
  }

  try {
    const oauth2Client = createOAuth2Client();
    oauth2Client.setCredentials({ refresh_token });
    const { credentials } = await oauth2Client.refreshAccessToken();

    res.json({
      tokens: {
        access_token: credentials.access_token,
        expiry_date: credentials.expiry_date,
        token_type: credentials.token_type
      }
    });
  } catch (error) {
    console.error('[Token Refresh Error]', error.message);
    res.status(500).json({ error: 'Failed to refresh token', details: error.message });
  }
});

/**
 * GET /auth/me
 * Returns the current user's profile.
 */
router.get('/me', async (req, res) => {
  const authHeader = req.headers.authorization;
  if (!authHeader || !authHeader.startsWith('Bearer ')) {
    return res.status(401).json({ error: 'Missing authorization' });
  }

  try {
    const accessToken = authHeader.split(' ')[1];
    const oauth2Client = createOAuth2Client();
    oauth2Client.setCredentials({ access_token: accessToken });

    const oauth2 = google.oauth2({ version: 'v2', auth: oauth2Client });
    const { data: userInfo } = await oauth2.userinfo.get();

    res.json({
      user: {
        id: userInfo.id,
        email: userInfo.email,
        name: userInfo.name,
        picture: userInfo.picture
      }
    });
  } catch (error) {
    console.error('[User Info Error]', error.message);
    res.status(401).json({ error: 'Invalid or expired token' });
  }
});

/**
 * POST /auth/revoke
 * Revoke an access token (sign out).
 */
router.post('/revoke', async (req, res) => {
  const authHeader = req.headers.authorization;
  if (!authHeader || !authHeader.startsWith('Bearer ')) {
    return res.status(401).json({ error: 'Missing authorization' });
  }

  try {
    const accessToken = authHeader.split(' ')[1];
    const oauth2Client = createOAuth2Client();
    await oauth2Client.revokeToken(accessToken);
    res.json({ success: true, message: 'Token revoked' });
  } catch (error) {
    console.error('[Revoke Error]', error.message);
    res.json({ success: true, message: 'Token revoked (may have already expired)' });
  }
});

module.exports = router;
