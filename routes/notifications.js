const express = require('express');
const db = require('../db');

const router = express.Router();

const asyncHandler = (fn) => (req, res, next) =>
  Promise.resolve(fn(req, res, next)).catch(next);

// Notifications (legacy `notifications` table)
// GET /api/notifications?notifiedDriverId=1&seen=0&limit=50&offset=0
router.get(
  '/',
  asyncHandler(async (req, res) => {
    const notifiedDriverIdRaw = req.query.notifiedDriverId;
    const notifiedDriverId =
      notifiedDriverIdRaw != null ? parseInt(String(notifiedDriverIdRaw), 10) : null;

    const seenRaw = req.query.seen;
    const seen =
      seenRaw == null
        ? null
        : String(seenRaw) === '1' || String(seenRaw).toLowerCase() === 'true'
          ? 1
          : 0;

    const limit = Math.min(parseInt(req.query.limit, 10) || 50, 200);
    const offset = parseInt(req.query.offset, 10) || 0;

    const where = [];
    const params = [];

    if (notifiedDriverIdRaw != null) {
      if (Number.isNaN(notifiedDriverId) || notifiedDriverId <= 0) {
        return res.status(400).json({ error: 'Invalid notifiedDriverId' });
      }
      where.push('n.notified_driver_id = ?');
      params.push(notifiedDriverId);
    }

    if (seenRaw != null) {
      where.push('n.seen = ?');
      params.push(seen);
    }

    let sql = `
      SELECT
        n.notification_id,
        n.alert_id,
        n.notified_driver_id,
        n.seen,
        n.notified_at,
        e.driver_id as alert_driver_id,
        e.latitude,
        e.longitude,
        e.status as alert_status,
        e.created_at as alert_created_at,
        d.full_name as notified_driver_name,
        d.email as notified_driver_email,
        d.taxi_matricule as notified_driver_taxi,
        a_driver.full_name as alert_driver_name,
        a_driver.taxi_matricule as alert_driver_taxi
      FROM notifications n
      LEFT JOIN emergency_alerts e ON e.alert_id = n.alert_id
      LEFT JOIN drivers d ON d.driver_id = n.notified_driver_id
      LEFT JOIN drivers a_driver ON a_driver.driver_id = e.driver_id
    `;

    if (where.length > 0) {
      sql += ` WHERE ${where.join(' AND ')}`;
    }

    sql += ' ORDER BY n.notified_at DESC, n.notification_id DESC LIMIT ? OFFSET ?';
    params.push(limit, offset);

    const [rows] = await db.query(sql, params);
    res.json({ success: true, notifications: rows || [] });
  })
);

router.get(
  '/:notificationId',
  asyncHandler(async (req, res) => {
    const notificationId = parseInt(req.params.notificationId, 10);
    if (Number.isNaN(notificationId) || notificationId <= 0) {
      return res.status(400).json({ error: 'Invalid notificationId' });
    }

    const [rows] = await db.query(
      `
      SELECT
        notification_id,
        alert_id,
        notified_driver_id,
        seen,
        notified_at
      FROM notifications
      WHERE notification_id = ?
      LIMIT 1
      `,
      [notificationId]
    );

    if (!rows || rows.length === 0) {
      return res.status(404).json({ error: 'Notification not found' });
    }

    res.json({ success: true, notification: rows[0] });
  })
);

// POST /api/notifications
// { "alertId": 1, "notifiedDriverId": 2 }
router.post(
  '/',
  asyncHandler(async (req, res) => {
    const { alertId, notifiedDriverId } = req.body || {};

    const alertIdNum = parseInt(String(alertId), 10);
    const notifiedDriverIdNum = parseInt(String(notifiedDriverId), 10);

    if (Number.isNaN(alertIdNum) || alertIdNum <= 0) {
      return res.status(400).json({ error: 'Valid alertId is required' });
    }
    if (Number.isNaN(notifiedDriverIdNum) || notifiedDriverIdNum <= 0) {
      return res.status(400).json({ error: 'Valid notifiedDriverId is required' });
    }

    const [result] = await db.query(
      'INSERT INTO notifications (alert_id, notified_driver_id, seen) VALUES (?, ?, 0)',
      [alertIdNum, notifiedDriverIdNum]
    );

    res.status(201).json({ success: true, notificationId: result.insertId });
  })
);

// PUT /api/notifications/:notificationId/seen
// { "seen": true }
router.put(
  '/:notificationId/seen',
  asyncHandler(async (req, res) => {
    const notificationId = parseInt(req.params.notificationId, 10);
    if (Number.isNaN(notificationId) || notificationId <= 0) {
      return res.status(400).json({ error: 'Invalid notificationId' });
    }

    const seenRaw = req.body?.seen;
    const seen =
      seenRaw === true || String(seenRaw) === '1' || String(seenRaw).toLowerCase() === 'true'
        ? 1
        : 0;

    await db.query('UPDATE notifications SET seen = ? WHERE notification_id = ?', [seen, notificationId]);
    res.json({ success: true });
  })
);

module.exports = router;

