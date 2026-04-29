const express = require('express');
const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');
const db = require('../db');
const multer = require('multer');
const path = require('path');
const nodemailer = require('nodemailer');
const crypto = require('crypto');
const { OAuth2Client } = require('google-auth-library');
const appleSignin = require('apple-signin-auth');

const router = express.Router();

// Configure multer for file uploads
const storage = multer.diskStorage({
  destination: (req, file, cb) => {
    cb(null, 'uploads/');
  },
  filename: (req, file, cb) => {
    const uniqueSuffix = Date.now() + '-' + Math.round(Math.random() * 1E9);
    cb(null, file.fieldname + '-' + uniqueSuffix + path.extname(file.originalname));
  }
});

const upload = multer({ storage: storage });

const transporter = nodemailer.createTransport({
  host: process.env.SMTP_HOST || '',
  port: parseInt(process.env.SMTP_PORT || '587', 10),
  secure: process.env.SMTP_SECURE === 'true',
  auth: process.env.SMTP_USER && process.env.SMTP_PASS ? {
    user: process.env.SMTP_USER,
    pass: process.env.SMTP_PASS
  } : undefined
});

const emailEnabled = Boolean(process.env.SMTP_HOST && process.env.SMTP_USER && process.env.SMTP_PASS);
const googleClient = new OAuth2Client(process.env.GOOGLE_CLIENT_ID);

const sendPasswordResetEmail = async (email, token) => {
  const resetUrl = `${process.env.FRONTEND_URL || 'http://localhost:8080'}/reset-password?token=${token}`;
  const message = {
    from: process.env.PASSWORD_RESET_FROM || process.env.SMTP_USER || 'no-reply@taxiapp.com',
    to: email,
    subject: 'TaxiApp password reset request',
    text: `A password reset was requested for your TaxiApp account. Use the token below to reset your password:\n\n${token}\n\nIf your app accepts links, open:\n${resetUrl}\n\nIf you did not request this, ignore this email.`,
  };

  if (emailEnabled) {
    await transporter.sendMail(message);
  } else {
    console.log('Password reset email not sent because SMTP is not configured.');
    console.log('Reset token:', token);
    console.log('Reset link:', resetUrl);
  }
};

const verifySocialUser = async ({ provider, idToken, accessToken }) => {
  if (provider === 'google') {
    if (!process.env.GOOGLE_CLIENT_ID) {
      throw new Error('Google login is not configured on the server');
    }
    if (!idToken) throw new Error('Google ID token is required');

    const ticket = await googleClient.verifyIdToken({
      idToken,
      audience: process.env.GOOGLE_CLIENT_ID,
    });
    const payload = ticket.getPayload();

    if (!payload || !payload.email) {
      throw new Error('Unable to verify Google user');
    }

    return {
      providerId: payload.sub,
      email: payload.email.toLowerCase(),
      username: payload.name || payload.email.split('@')[0],
    };
  }

  if (provider === 'facebook') {
    if (!process.env.FACEBOOK_APP_ID || !process.env.FACEBOOK_APP_SECRET) {
      throw new Error('Facebook login is not configured on the server');
    }
    if (!accessToken) throw new Error('Facebook access token is required');

    const response = await fetch(`https://graph.facebook.com/me?fields=id,name,email&access_token=${accessToken}`);
    const fbData = await response.json();

    if (!fbData || !fbData.id || !fbData.email) {
      throw new Error('Unable to verify Facebook user');
    }

    return {
      providerId: fbData.id,
      email: fbData.email.toLowerCase(),
      username: fbData.name || fbData.email.split('@')[0],
    };
  }

  if (provider === 'apple') {
    if (!process.env.APPLE_CLIENT_ID) {
      throw new Error('Apple login is not configured on the server');
    }
    if (!idToken) throw new Error('Apple identity token is required');

    const payload = await appleSignin.verifyIdToken(idToken, {
      audience: process.env.APPLE_CLIENT_ID || process.env.APPLE_SERVICES_ID,
      ignoreExpiration: false,
    });

    if (!payload || !payload.sub) {
      throw new Error('Unable to verify Apple user');
    }

    if (!payload.email) {
      throw new Error('Apple login did not provide an email address');
    }

    return {
      providerId: payload.sub,
      email: payload.email.toLowerCase(),
      username: payload.email.split('@')[0],
    };
  }

  throw new Error('Unsupported social provider');
};

// Middleware to verify JWT token
const authenticateToken = (req, res, next) => {
  const authHeader = req.headers['authorization'];
  const token = authHeader && authHeader.split(' ')[1];

  if (!token) {
    return res.status(401).json({ error: 'Access token required' });
  }

  jwt.verify(token, process.env.JWT_SECRET, (err, user) => {
    if (err) {
      return res.status(403).json({ error: 'Invalid or expired token' });
    }
    req.user = user;
    next();
  });
};

// Password reset request
router.post('/request-password-reset', async (req, res) => {
  try {
    const email = typeof req.body.email === 'string' ? req.body.email.trim().toLowerCase() : '';
    if (!email || !email.includes('@')) {
      return res.status(400).json({ error: 'Valid email is required' });
    }

    const [users] = await db.query('SELECT id FROM users WHERE email = ?', [email]);
    if (users.length === 0) {
      return res.json({ success: true, message: 'If that account exists, a password reset token has been sent.' });
    }

    const token = crypto.randomBytes(32).toString('hex');
    const expiresAt = new Date(Date.now() + 60 * 60 * 1000);
    const expiresAtSql = expiresAt.toISOString().slice(0, 19).replace('T', ' ');

    await db.query(
      'UPDATE users SET reset_token = ?, reset_token_expires = ? WHERE id = ?',
      [token, expiresAtSql, users[0].id]
    );

    await sendPasswordResetEmail(email, token);

    res.json({ success: true, message: 'If that account exists, a password reset token has been sent.' });
  } catch (error) {
    console.error('Password reset request error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// Complete password reset with token
router.post('/reset-password', async (req, res) => {
  try {
    const { token, newPassword } = req.body;
    if (!token || typeof token !== 'string' || !newPassword || typeof newPassword !== 'string') {
      return res.status(400).json({ error: 'Reset token and new password are required' });
    }

    if (newPassword.length < 6) {
      return res.status(400).json({ error: 'New password must be at least 6 characters' });
    }

    const [users] = await db.query(
      'SELECT id, reset_token_expires FROM users WHERE reset_token = ?',
      [token]
    );

    if (users.length === 0) {
      return res.status(400).json({ error: 'Invalid or expired reset token' });
    }

    const user = users[0];
    const expiresAt = new Date(user.reset_token_expires);
    if (expiresAt < new Date()) {
      return res.status(400).json({ error: 'Reset token has expired' });
    }

    const passwordHash = await bcrypt.hash(newPassword, 10);
    await db.query(
      'UPDATE users SET password_hash = ?, reset_token = NULL, reset_token_expires = NULL WHERE id = ?',
      [passwordHash, user.id]
    );

    res.json({ success: true, message: 'Password has been reset successfully' });
  } catch (error) {
    console.error('Password reset error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// Social sign in / registration
router.post('/social-login', async (req, res) => {
  try {
    const { provider, idToken, accessToken } = req.body;
    if (!provider || typeof provider !== 'string') {
      return res.status(400).json({ error: 'Social provider is required' });
    }

    const socialUser = await verifySocialUser({ provider, idToken, accessToken });
    const normalizedEmail = socialUser.email.trim().toLowerCase();
    const normalizedUsername = socialUser.username.trim();

    const [existing] = await db.query(
      'SELECT id, username, email, role FROM users WHERE (provider = ? AND provider_id = ?) OR email = ?',
      [provider, socialUser.providerId, normalizedEmail]
    );

    let userRecord;
    if (existing.length > 0) {
      userRecord = existing[0];
      await db.query(
        'UPDATE users SET username = ?, email = ?, provider = ?, provider_id = ? WHERE id = ?',
        [normalizedUsername, normalizedEmail, provider, socialUser.providerId, userRecord.id]
      );
    } else {
      const randomPassword = crypto.randomBytes(16).toString('hex');
      const passwordHash = await bcrypt.hash(randomPassword, 10);
      const [result] = await db.query(
        'INSERT INTO users (username, email, password_hash, role, provider, provider_id) VALUES (?, ?, ?, ?, ?, ?)',
        [normalizedUsername, normalizedEmail, passwordHash, 'driver', provider, socialUser.providerId]
      );
      userRecord = { id: result.insertId, username: normalizedUsername, email: normalizedEmail, role: 'driver' };
    }

    const token = jwt.sign(
      {
        id: userRecord.id,
        username: userRecord.username,
        email: userRecord.email,
        role: userRecord.role
      },
      process.env.JWT_SECRET,
      { expiresIn: '24h' }
    );

    res.json({
      success: true,
      token,
      user: {
        id: userRecord.id,
        username: userRecord.username,
        email: userRecord.email,
        role: userRecord.role
      }
    });
  } catch (error) {
    console.error('Social login error:', error);
    res.status(500).json({ error: error.message || 'Internal server error' });
  }
});

// Register new user/driver
router.post('/register', async (req, res) => {
  try {
    const { username, email, password, role = 'driver', phone, vehicleModel, licensePlate } = req.body;

    const normalizedEmail = typeof email === 'string' ? email.trim().toLowerCase() : '';
    const normalizedUsername = typeof username === 'string' ? username.trim() : '';

    if (!normalizedUsername || !normalizedEmail || !password) {
      return res.status(400).json({ error: 'Username, email, and password are required' });
    }

    // Check if user already exists
    const [existing] = await db.query(
      'SELECT id FROM users WHERE email = ? OR username = ?',
      [normalizedEmail, normalizedUsername]
    );

    if (existing.length > 0) {
      return res.status(409).json({ error: 'User already exists' });
    }

    // Hash password
    const saltRounds = 10;
    const passwordHash = await bcrypt.hash(password, saltRounds);

    // Insert user
    const [result] = await db.query(
      'INSERT INTO users (username, email, password_hash, role) VALUES (?, ?, ?, ?)',
      [normalizedUsername, normalizedEmail, passwordHash, role]
    );

    const userId = result.insertId;

    // If driver, create taxi profile
    if (role === 'driver' && vehicleModel && licensePlate) {
      const taxiId = `TX-${userId.toString().padStart(4, '0')}`;
      await db.query(
        // lat/lng are required in the current schema; default to 0 until the driver sends location updates.
        'INSERT INTO taxis (taxi_id, lat, lng, is_online, vehicle_model, license_plate, driver_name, phone) VALUES (?, 0, 0, false, ?, ?, ?, ?)',
        [taxiId, vehicleModel, licensePlate, normalizedUsername, phone]
      );

      // Mirror driver profile into legacy `drivers` table (if present in your DB).
      // Auth still uses `users` as source of truth.
      try {
        await db.query(
          `
          INSERT INTO drivers (full_name, email, taxi_matricule, phone_number, password, is_online)
          VALUES (?, ?, ?, ?, ?, 0) AS new
          ON DUPLICATE KEY UPDATE
            full_name = new.full_name,
            email = new.email,
            phone_number = new.phone_number,
            password = new.password,
            is_online = new.is_online,
            updated_at = CURRENT_TIMESTAMP
          `,
          [normalizedUsername, normalizedEmail, licensePlate, phone || null, passwordHash]
        );
      } catch (e) {
        console.warn('Drivers table insert skipped:', e.message);
      }
    }

    res.status(201).json({
      success: true,
      message: 'User registered successfully',
      userId
    });
  } catch (error) {
    console.error('Registration error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// Login user by email + password
router.post('/login', async (req, res) => {
  try {
    const { email, password } = req.body;

    const normalizedEmail = typeof email === 'string' ? email.trim().toLowerCase() : '';

    if (!normalizedEmail || !password) {
      return res.status(400).json({ error: 'Email and password are required' });
    }

    const [users] = await db.query(
      'SELECT id, username, email, password_hash, role FROM users WHERE email = ?',
      [normalizedEmail]
    );

    if (users.length === 0) {
      return res.status(401).json({ error: 'Invalid credentials' });
    }

    const user = users[0];

    // Verify password
    const isValidPassword = await bcrypt.compare(password, user.password_hash);
    if (!isValidPassword) {
      return res.status(401).json({ error: 'Invalid credentials' });
    }

    // Generate JWT token
    const token = jwt.sign(
      {
        id: user.id,
        username: user.username,
        email: user.email,
        role: user.role
      },
      process.env.JWT_SECRET,
      { expiresIn: '24h' }
    );

    res.json({
      success: true,
      token,
      user: {
        id: user.id,
        username: user.username,
        email: user.email,
        role: user.role
      }
    });
  } catch (error) {
    console.error('Login error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// Get user profile
router.get('/profile', authenticateToken, async (req, res) => {
  try {
    const [users] = await db.query(
      'SELECT id, username, email, role, created_at FROM users WHERE id = ?',
      [req.user.id]
    );

    if (users.length === 0) {
      return res.status(404).json({ error: 'User not found' });
    }

    res.json({ success: true, user: users[0] });
  } catch (error) {
    console.error('Profile fetch error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// Update user profile
router.put('/profile', authenticateToken, upload.single('profileImage'), async (req, res) => {
  try {
    const { username, phone } = req.body;
    const updates = [];
    const values = [];

    if (username) {
      updates.push('username = ?');
      values.push(username);
    }

    if (phone) {
      updates.push('phone = ?');
      values.push(phone);
    }

    if (req.file) {
      const imagePath = `/uploads/${req.file.filename}`;
      updates.push('profile_image = ?');
      values.push(imagePath);
    }

    if (updates.length === 0) {
      return res.status(400).json({ error: 'No valid fields to update' });
    }

    values.push(req.user.id);

    await db.query(
      `UPDATE users SET ${updates.join(', ')} WHERE id = ?`,
      values
    );

    res.json({ success: true, message: 'Profile updated successfully' });
  } catch (error) {
    console.error('Profile update error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// Change password
router.put('/password', authenticateToken, async (req, res) => {
  try {
    const { currentPassword, newPassword } = req.body;

    if (!currentPassword || !newPassword) {
      return res.status(400).json({ error: 'Current and new password are required' });
    }

    if (newPassword.length < 6) {
      return res.status(400).json({ error: 'New password must be at least 6 characters' });
    }

    // Get current password hash
    const [users] = await db.query(
      'SELECT password_hash FROM users WHERE id = ?',
      [req.user.id]
    );

    if (users.length === 0) {
      return res.status(404).json({ error: 'User not found' });
    }

    // Verify current password
    const isValidPassword = await bcrypt.compare(currentPassword, users[0].password_hash);
    if (!isValidPassword) {
      return res.status(401).json({ error: 'Current password is incorrect' });
    }

    // Hash new password
    const saltRounds = 10;
    const newPasswordHash = await bcrypt.hash(newPassword, saltRounds);

    // Update password
    await db.query(
      'UPDATE users SET password_hash = ? WHERE id = ?',
      [newPasswordHash, req.user.id]
    );

    res.json({ success: true, message: 'Password changed successfully' });
  } catch (error) {
    console.error('Password change error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

module.exports = router;
module.exports.authenticateToken = authenticateToken;
