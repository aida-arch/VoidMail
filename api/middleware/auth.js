const { google } = require('googleapis');

async function requireAuth(req, res, next) {
  try {
    const authHeader = req.headers.authorization;
    if (!authHeader || !authHeader.startsWith('Bearer ')) {
      return res.status(401).json({ error: 'Missing or invalid authorization header' });
    }

    const accessToken = authHeader.split(' ')[1];

    const oauth2Client = new google.auth.OAuth2(
      process.env.GOOGLE_CLIENT_ID,
      process.env.GOOGLE_CLIENT_SECRET,
      process.env.GOOGLE_REDIRECT_URI
    );

    oauth2Client.setCredentials({ access_token: accessToken });

    const oauth2 = google.oauth2({ version: 'v2', auth: oauth2Client });
    const { data: userInfo } = await oauth2.userinfo.get();

    req.oauth2Client = oauth2Client;
    req.user = {
      id: userInfo.id,
      email: userInfo.email,
      name: userInfo.name,
      picture: userInfo.picture
    };

    next();
  } catch (error) {
    console.error('[Auth Error]', error.message);
    if (error.code === 401 || error.message.includes('invalid_token')) {
      return res.status(401).json({ error: 'Token expired or invalid', code: 'TOKEN_EXPIRED' });
    }
    return res.status(401).json({ error: 'Authentication failed' });
  }
}

async function optionalAuth(req, res, next) {
  const authHeader = req.headers.authorization;
  if (!authHeader || !authHeader.startsWith('Bearer ')) {
    return next();
  }

  try {
    await requireAuth(req, res, next);
  } catch {
    next();
  }
}

module.exports = { requireAuth, optionalAuth };
