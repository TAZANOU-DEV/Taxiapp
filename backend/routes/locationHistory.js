const express = require('express');
const db = require('../db');

const router = express.Router();

const asyncHandler = (fn) => (req, res, next) =>
  Promise.resolve(fn(req, res, next)).catch(next);

// Driver location history (legacy `location_history` table)
// GET /api/location-history?driverId=1&limit=50&offset=0
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
      if (Number.isNaN(driverId) || driverId <= 0) {
        return res.status(400).json({ error: 'Invalid driverId' });
      }
      where.push('lh.driver_id = ?');
      params.push(driverId);
    }

    let sql = `
      SELECT
        lh.location_id,
        lh.driver_id,
        lh.latitude,
        lh.longitude,
        lh.recorded_at,
        d.full_name,
        d.email,
        d.taxi_matricule
      FROM location_history lh
      LEFT JOIN drivers d ON d.driver_id = lh.driver_id
    `;

    if (where.length > 0) {
      sql += ` WHERE ${where.join(' AND ')}`;
    }

    sql += ' ORDER BY lh.recorded_at DESC, lh.location_id DESC LIMIT ? OFFSET ?';
    params.push(limit, offset);

    const [rows] = await db.query(sql, params);
    res.json({ success: true, locations: rows || [] });
  })
);

// Convenience: GET /api/location-history/driver/:driverId
router.get(
  '/driver/:driverId',
  asyncHandler(async (req, res) => {
    const driverId = parseInt(req.params.driverId, 10);
    if (Number.isNaN(driverId) || driverId <= 0) {
      return res.status(400).json({ error: 'Invalid driverId' });
    }

    const limit = Math.min(parseInt(req.query.limit, 10) || 50, 200);
    const offset = parseInt(req.query.offset, 10) || 0;

    const [rows] = await db.query(
      `
      SELECT
        location_id,
        driver_id,
        latitude,
        longitude,
        recorded_at
      FROM location_history
      WHERE driver_id = ?
      ORDER BY recorded_at DESC, location_id DESC
      LIMIT ? OFFSET ?
      `,
      [driverId, limit, offset]
    );

    res.json({ success: true, locations: rows || [] });
  })
);

// POST /api/location-history
// { "driverId": 1, "latitude": 3.86, "longitude": 11.51 }
router.post(
  '/',
  asyncHandler(async (req, res) => {
    const { driverId, latitude = null, longitude = null } = req.body || {};

    const driverIdNum = parseInt(String(driverId), 10);
    if (Number.isNaN(driverIdNum) || driverIdNum <= 0) {
      return res.status(400).json({ error: 'Valid driverId is required' });
    }

    const latNum = latitude == null ? null : Number(latitude);
    const lngNum = longitude == null ? null : Number(longitude);
    if ((latitude != null && Number.isNaN(latNum)) || (longitude != null && Number.isNaN(lngNum))) {
      return res.status(400).json({ error: 'latitude/longitude must be numbers (or omitted)' });
    }

    const [result] = await db.query(
      'INSERT INTO location_history (driver_id, latitude, longitude) VALUES (?, ?, ?)',
      [driverIdNum, latNum, lngNum]
    );

    res.status(201).json({ success: true, locationId: result.insertId });
  })
);

module.exports = router;

