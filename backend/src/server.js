require('dotenv').config();
const express = require('express');
const cors = require('cors');

const authRoutes = require('./routes/auth');
const gmailRoutes = require('./routes/gmail');
const calendarRoutes = require('./routes/calendar');
const helixRoutes = require('./routes/helix');

const app = express();
const PORT = process.env.PORT || 3000;

// Middleware
app.use(cors());
app.use(express.json({ limit: '10mb' }));
app.use(express.urlencoded({ extended: true }));

// Request logging
app.use((req, res, next) => {
  console.log(`[${new Date().toISOString()}] ${req.method} ${req.path}`);
  next();
});

// Routes
app.use('/auth', authRoutes);
app.use('/api/gmail', gmailRoutes);
app.use('/api/calendar', calendarRoutes);
app.use('/api/helix', helixRoutes);

// Health check
app.get('/health', (req, res) => {
  res.json({
    status: 'ok',
    service: 'VoidMail Backend',
    version: '1.0.0',
    timestamp: new Date().toISOString()
  });
});

// Error handling
app.use((err, req, res, next) => {
  console.error('[Error]', err.message);
  res.status(err.status || 500).json({
    error: err.message || 'Internal server error',
    code: err.code || 'UNKNOWN_ERROR'
  });
});

// 404 handler
app.use((req, res) => {
  res.status(404).json({ error: 'Not found', path: req.path });
});

app.listen(PORT, () => {
  console.log(`\n  VoidMail Backend running on http://localhost:${PORT}`);
  console.log(`  Google Project: ${process.env.GOOGLE_PROJECT_ID}`);
  console.log(`  Helix-o1 AI: Gemini 2.0 Flash`);
  console.log(`  Environment: ${process.env.NODE_ENV}\n`);
});
