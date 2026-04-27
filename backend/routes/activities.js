const express = require('express');
const db = require('../db');

const router = express.Router();

const asyncHandler = (fn) => (req, res, next) =>
  Promise.resolve(fn(req, res, next)).catch(next);

const allowedTypes = new Set(['emergency', 'location', 'order', 'status']);

// List activities with optional filters:
//   GET /api/activities?taxiId=TX-0001&type=emergency&limit=50&offset=0
router.get(
  '/',
  asyncHandler(async (req, res) => {
    const taxiId = req.query.taxiId ? String(req.query.taxiId) : null;
    const type = req.query.type ? String(req.query.type) : null;
    const limit = Math.min(parseInt(req.query.limit, 10) || 50, 200);
    const offset = parseInt(req.query.offset, 10) || 0;

    const where = [];
    const params = [];

    if (taxiId) {
      where.push('a.taxi_id = ?');
      params.push(taxiId);
    }

    if (type) {
      if (!allowedTypes.has(type)) {
        return res.status(400).json({ error: `Invalid type. Allowed: ${Array.from(allowedTypes).join(', ')}` });
      }
      where.push('a.type = ?');
      params.push(type);
    }

    let sql = `
      SELECT
        a.*,
        t.driver_name,
        t.license_plate
      FROM activities a
      LEFT JOIN taxis t ON a.taxi_id = t.taxi_id
    `;

    if (where.length > 0) {
      sql += ` WHERE ${where.join(' AND ')}`;
    }

    sql += ' ORDER BY a.created_at DESC LIMIT ? OFFSET ?';
    params.push(limit, offset);

    const [activities] = await db.query(sql, params);
    res.json({ success: true, activities: activities || [] });
  })
);

// Convenience: GET /api/activities/:taxiId
router.get(
  '/:taxiId',
  asyncHandler(async (req, res) => {
    const taxiId = req.params.taxiId;
    const limit = Math.min(parseInt(req.query.limit, 10) || 50, 200);
    const offset = parseInt(req.query.offset, 10) || 0;

    const [activities] = await db.query(
      `
      SELECT
        a.*,
        t.driver_name,
        t.license_plate
      FROM activities a
      LEFT JOIN taxis t ON a.taxi_id = t.taxi_id
      WHERE a.taxi_id = ?
      ORDER BY a.created_at DESC
      LIMIT ? OFFSET ?
      `,
      [taxiId, limit, offset]
    );

    res.json({ success: true, activities: activities || [] });
  })
);

// Create activity (optional helper if you want the app to write custom activities)
router.post(
  '/',
  asyncHandler(async (req, res) => {
    const { taxiId, title, description = null, type = 'status' } = req.body || {};

    if (!taxiId || !title) {
      return res.status(400).json({ error: 'taxiId and title are required' });
    }

    if (!allowedTypes.has(type)) {
      return res.status(400).json({ error: `Invalid type. Allowed: ${Array.from(allowedTypes).join(', ')}` });
    }

    const [result] = await db.query(
      'INSERT INTO activities (taxi_id, title, description, type) VALUES (?, ?, ?, ?)',
      [taxiId, title, description, type]
    );

    res.status(201).json({ success: true, id: result.insertId });
  })
);

module.exports = router;

