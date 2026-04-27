const express = require('express');
const db = require('../db');

const router = express.Router();

const asyncHandler = (fn) => (req, res, next) =>
  Promise.resolve(fn(req, res, next)).catch(next);

const allowedStatus = new Set(['pending', 'resolved']);

// List emergency alerts
// GET /api/emergency-alerts?driverId=1&status=pending&limit=50&offset=0
router.get(
  '/',
  asyncHandler(async (req, res) => {
    const driverIdRaw = req.query.driverId;
    const driverId = driverIdRaw != null ? parseInt(String(driverIdRaw), 10) : null;
    const status = req.query.status != null ? String(req.query.status) : null;
    const limit = Math.min(parseInt(req.query.limit, 10) || 50, 200);
    const offset = parseInt(req.query.offset, 10) || 0;

    const where = [];
    const params = [];

    if (driverIdRaw != null) {
      if (Number.isNaN(driverId) || driverId <= 0) {
        return res.status(400).json({ error: 'Invalid driverId' });
      }
      where.push('e.driver_id = ?');
      params.push(driverId);
    }

    if (status != null) {
      if (!allowedStatus.has(status)) {
        return res.status(400).json({ error: `Invalid status. Allowed: ${Array.from(allowedStatus).join(', ')}` });
      }
      where.push('e.status = ?');
      params.push(status);
    }

    let sql = `
      SELECT
        e.alert_id,
        e.driver_id,
        e.latitude,
        e.longitude,
        e.status,
        e.created_at,
        d.full_name,
        d.email,
        d.taxi_matricule
      FROM emergency_alerts e
      LEFT JOIN drivers d ON d.driver_id = e.driver_id
    `;

    if (where.length > 0) {
      sql += ` WHERE ${where.join(' AND ')}`;
    }

    sql += ' ORDER BY e.created_at DESC, e.alert_id DESC LIMIT ? OFFSET ?';
    params.push(limit, offset);

    const [alerts] = await db.query(sql, params);
    res.json({ success: true, alerts: alerts || [] });
  })
);

// Get one alert by id
router.get(
  '/:alertId',
  asyncHandler(async (req, res) => {
    const alertId = parseInt(req.params.alertId, 10);
    if (Number.isNaN(alertId) || alertId <= 0) {
      return res.status(400).json({ error: 'Invalid alertId' });
    }

    const [rows] = await db.query(
      `
      SELECT
        e.alert_id,
        e.driver_id,
        e.latitude,
        e.longitude,
        e.status,
        e.created_at,
        d.full_name,
        d.email,
        d.taxi_matricule
      FROM emergency_alerts e
      LEFT JOIN drivers d ON d.driver_id = e.driver_id
      WHERE e.alert_id = ?
      LIMIT 1
      `,
      [alertId]
    );

    if (!rows || rows.length === 0) {
      return res.status(404).json({ error: 'Emergency alert not found' });
    }

    res.json({ success: true, alert: rows[0] });
  })
);

// Convenience: alerts for a driver
router.get(
  '/driver/:driverId',
  asyncHandler(async (req, res) => {
    const driverId = parseInt(req.params.driverId, 10);
    if (Number.isNaN(driverId) || driverId <= 0) {
      return res.status(400).json({ error: 'Invalid driverId' });
    }

    const limit = Math.min(parseInt(req.query.limit, 10) || 50, 200);
    const offset = parseInt(req.query.offset, 10) || 0;
    const status = req.query.status != null ? String(req.query.status) : null;

    const where = ['e.driver_id = ?'];
    const params = [driverId];

    if (status != null) {
      if (!allowedStatus.has(status)) {
        return res.status(400).json({ error: `Invalid status. Allowed: ${Array.from(allowedStatus).join(', ')}` });
      }
      where.push('e.status = ?');
      params.push(status);
    }

    const [alerts] = await db.query(
      `
      SELECT
        e.alert_id,
        e.driver_id,
        e.latitude,
        e.longitude,
        e.status,
        e.created_at
      FROM emergency_alerts e
      WHERE ${where.join(' AND ')}
      ORDER BY e.created_at DESC, e.alert_id DESC
      LIMIT ? OFFSET ?
      `,
      [...params, limit, offset]
    );

    res.json({ success: true, alerts: alerts || [] });
  })
);

// Create an emergency alert
// POST /api/emergency-alerts
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
      'INSERT INTO emergency_alerts (driver_id, latitude, longitude, status) VALUES (?, ?, ?, ?)',
      [driverIdNum, latNum, lngNum, 'pending']
    );

    res.status(201).json({ success: true, alertId: result.insertId });
  })
);

// Update alert status (resolve)
router.put(
  '/:alertId/status',
  asyncHandler(async (req, res) => {
    const alertId = parseInt(req.params.alertId, 10);
    if (Number.isNaN(alertId) || alertId <= 0) {
      return res.status(400).json({ error: 'Invalid alertId' });
    }

    const status = req.body?.status != null ? String(req.body.status) : null;
    if (!status || !allowedStatus.has(status)) {
      return res.status(400).json({ error: `status is required. Allowed: ${Array.from(allowedStatus).join(', ')}` });
    }

    await db.query('UPDATE emergency_alerts SET status = ? WHERE alert_id = ?', [status, alertId]);
    res.json({ success: true });
  })
);

module.exports = router;
