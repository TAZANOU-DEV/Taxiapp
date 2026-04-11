const express = require('express');
const db = require('../db');

const router = express.Router();

const asyncHandler = (fn) => (req, res, next) =>
  Promise.resolve(fn(req, res, next)).catch(next);

// List drivers (drivers are users where role = 'driver')
// Optional: ?limit=50&offset=0
router.get(
  '/',
  asyncHandler(async (req, res) => {
    const limit = Math.min(parseInt(req.query.limit, 10) || 50, 200);
    const offset = parseInt(req.query.offset, 10) || 0;

    const [drivers] = await db.query(
      `
      SELECT
        u.id as user_id,
        u.username,
        u.email,
        u.phone as user_phone,
        u.is_active,
        u.created_at as user_created_at,
        u.updated_at as user_updated_at,
        t.taxi_id,
        t.vehicle_model,
        t.license_plate,
        t.is_online,
        t.lat,
        t.lng,
        t.phone as taxi_phone,
        t.created_at as taxi_created_at,
        t.updated_at as taxi_updated_at
      FROM users u
      LEFT JOIN taxis t ON t.driver_name = u.username
      WHERE u.role = 'driver'
      ORDER BY u.id DESC
      LIMIT ? OFFSET ?
      `,
      [limit, offset]
    );

    res.json({ success: true, drivers });
  })
);

// Get one driver by user id
router.get(
  '/:userId',
  asyncHandler(async (req, res) => {
    const userId = parseInt(req.params.userId, 10);
    if (Number.isNaN(userId)) {
      return res.status(400).json({ error: 'Invalid userId' });
    }

    const [rows] = await db.query(
      `
      SELECT
        u.id as user_id,
        u.username,
        u.email,
        u.phone as user_phone,
        u.is_active,
        u.created_at as user_created_at,
        u.updated_at as user_updated_at,
        t.taxi_id,
        t.vehicle_model,
        t.license_plate,
        t.is_online,
        t.lat,
        t.lng,
        t.phone as taxi_phone,
        t.created_at as taxi_created_at,
        t.updated_at as taxi_updated_at
      FROM users u
      LEFT JOIN taxis t ON t.driver_name = u.username
      WHERE u.id = ? AND u.role = 'driver'
      LIMIT 1
      `,
      [userId]
    );

    if (!rows || rows.length === 0) {
      return res.status(404).json({ error: 'Driver not found' });
    }

    res.json({ success: true, driver: rows[0] });
  })
);

module.exports = router;

