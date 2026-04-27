const express = require('express');
const db = require('../db');

const router = express.Router();

const asyncHandler = (fn) => (req, res, next) =>
  Promise.resolve(fn(req, res, next)).catch(next);

// Legacy `activity` table API (driver-centric activity log)
// Filters:
//   GET /api/activity?driverId=1&limit=50&offset=0
router.get(
  '/',
  asyncHandler(async (req, res) => {
    const driverIdRaw = req.query.driverId;
    const driverId =
      driverIdRaw != null ? parseInt(String(driverIdRaw), 10) : null;
    const limit = Math.min(parseInt(req.query.limit, 10) || 50, 200);
    const offset = parseInt(req.query.offset, 10) || 0;

    const where = [];
    const params = [];

    if (driverIdRaw != null) {
      if (Number.isNaN(driverId)) {
        return res.status(400).json({ error: 'Invalid driverId' });
      }
      where.push('a.driver_id = ?');
      params.push(driverId);
    }

    let sql = `
      SELECT
        a.activity_id,
        a.driver_id,
        a.action,
        a.timestamp,
        d.full_name,
        d.email,
        d.taxi_matricule
      FROM activity a
      LEFT JOIN drivers d ON d.driver_id = a.driver_id
    `;

    if (where.length > 0) {
      sql += ` WHERE ${where.join(' AND ')}`;
    }

    sql += ' ORDER BY a.timestamp DESC, a.activity_id DESC LIMIT ? OFFSET ?';
    params.push(limit, offset);

    const [activities] = await db.query(sql, params);
    res.json({ success: true, activities: activities || [] });
  })
);

// Convenience: GET /api/activity/driver/:driverId
router.get(
  '/driver/:driverId',
  asyncHandler(async (req, res) => {
    const driverId = parseInt(req.params.driverId, 10);
    if (Number.isNaN(driverId)) {
      return res.status(400).json({ error: 'Invalid driverId' });
    }

    const limit = Math.min(parseInt(req.query.limit, 10) || 50, 200);
    const offset = parseInt(req.query.offset, 10) || 0;

    const [activities] = await db.query(
      `
      SELECT
        a.activity_id,
        a.driver_id,
        a.action,
        a.timestamp,
        d.full_name,
        d.email,
        d.taxi_matricule
      FROM activity a
      LEFT JOIN drivers d ON d.driver_id = a.driver_id
      WHERE a.driver_id = ?
      ORDER BY a.timestamp DESC, a.activity_id DESC
      LIMIT ? OFFSET ?
      `,
      [driverId, limit, offset]
    );

    res.json({ success: true, activities: activities || [] });
  })
);

// Create activity row
// POST /api/activity
// { "driverId": 1, "action": "Sent emergency alert" }
router.post(
  '/',
  asyncHandler(async (req, res) => {
    const { driverId, action } = req.body || {};

    const driverIdNum = parseInt(String(driverId), 10);
    if (Number.isNaN(driverIdNum) || driverIdNum <= 0) {
      return res.status(400).json({ error: 'Valid driverId is required' });
    }

    const actionStr = typeof action === 'string' ? action.trim() : '';
    if (!actionStr) {
      return res.status(400).json({ error: 'action is required' });
    }

    const [result] = await db.query(
      'INSERT INTO activity (driver_id, action) VALUES (?, ?)',
      [driverIdNum, actionStr]
    );

    res.status(201).json({ success: true, activityId: result.insertId });
  })
);

module.exports = router;

