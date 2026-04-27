const express = require('express');
const db = require('../db');

const router = express.Router();

const asyncHandler = (fn) => (req, res, next) =>
  Promise.resolve(fn(req, res, next)).catch(next);

const allowedStatus = new Set([
  'requested',
  'accepted',
  'on_way',
  'arrived',
  'completed',
  'cancelled',
]);

// List taxi orders
// GET /api/taxi-orders?fromTaxiId=TX-0001&toTaxiId=TX-0002&status=requested&limit=50&offset=0
router.get(
  '/',
  asyncHandler(async (req, res) => {
    const fromTaxiId = req.query.fromTaxiId ? String(req.query.fromTaxiId) : null;
    const toTaxiId = req.query.toTaxiId ? String(req.query.toTaxiId) : null;
    const status = req.query.status ? String(req.query.status) : null;
    const limit = Math.min(parseInt(req.query.limit, 10) || 50, 200);
    const offset = parseInt(req.query.offset, 10) || 0;

    const where = [];
    const params = [];

    if (fromTaxiId) {
      where.push('o.from_taxi_id = ?');
      params.push(fromTaxiId);
    }
    if (toTaxiId) {
      where.push('o.to_taxi_id = ?');
      params.push(toTaxiId);
    }
    if (status) {
      if (!allowedStatus.has(status)) {
        return res.status(400).json({ error: `Invalid status. Allowed: ${Array.from(allowedStatus).join(', ')}` });
      }
      where.push('o.status = ?');
      params.push(status);
    }

    let sql = `
      SELECT
        o.*,
        t_from.driver_name as from_driver_name,
        t_to.driver_name as to_driver_name
      FROM taxi_orders o
      LEFT JOIN taxis t_from ON o.from_taxi_id = t_from.taxi_id
      LEFT JOIN taxis t_to ON o.to_taxi_id = t_to.taxi_id
    `;

    if (where.length > 0) {
      sql += ` WHERE ${where.join(' AND ')}`;
    }

    sql += ' ORDER BY o.created_at DESC, o.id DESC LIMIT ? OFFSET ?';
    params.push(limit, offset);

    const [orders] = await db.query(sql, params);
    res.json({ success: true, orders: orders || [] });
  })
);

router.get(
  '/:orderId',
  asyncHandler(async (req, res) => {
    const orderId = parseInt(req.params.orderId, 10);
    if (Number.isNaN(orderId) || orderId <= 0) {
      return res.status(400).json({ error: 'Invalid orderId' });
    }

    const [rows] = await db.query(
      `
      SELECT
        o.*,
        t_from.driver_name as from_driver_name,
        t_to.driver_name as to_driver_name
      FROM taxi_orders o
      LEFT JOIN taxis t_from ON o.from_taxi_id = t_from.taxi_id
      LEFT JOIN taxis t_to ON o.to_taxi_id = t_to.taxi_id
      WHERE o.id = ?
      LIMIT 1
      `,
      [orderId]
    );

    if (!rows || rows.length === 0) {
      return res.status(404).json({ error: 'Order not found' });
    }

    res.json({ success: true, order: rows[0] });
  })
);

// Create order
// POST /api/taxi-orders
router.post(
  '/',
  asyncHandler(async (req, res) => {
    const {
      fromTaxiId,
      toTaxiId,
      pickupLat = null,
      pickupLng = null,
      dropoffLat = null,
      dropoffLng = null,
      reason = null,
      fare = null,
    } = req.body || {};

    if (!fromTaxiId || !toTaxiId) {
      return res.status(400).json({ error: 'fromTaxiId and toTaxiId are required' });
    }

    const [result] = await db.query(
      `
      INSERT INTO taxi_orders
        (from_taxi_id, to_taxi_id, status, pickup_lat, pickup_lng, dropoff_lat, dropoff_lng, reason, fare)
      VALUES
        (?, ?, 'requested', ?, ?, ?, ?, ?, ?)
      `,
      [fromTaxiId, toTaxiId, pickupLat, pickupLng, dropoffLat, dropoffLng, reason, fare]
    );

    res.status(201).json({ success: true, orderId: result.insertId });
  })
);

// Update status
// PUT /api/taxi-orders/:orderId/status
// { "status": "accepted" }
router.put(
  '/:orderId/status',
  asyncHandler(async (req, res) => {
    const orderId = parseInt(req.params.orderId, 10);
    if (Number.isNaN(orderId) || orderId <= 0) {
      return res.status(400).json({ error: 'Invalid orderId' });
    }

    const status = req.body?.status ? String(req.body.status) : null;
    if (!status || !allowedStatus.has(status)) {
      return res.status(400).json({ error: `status is required. Allowed: ${Array.from(allowedStatus).join(', ')}` });
    }

    await db.query('UPDATE taxi_orders SET status = ?, updated_at = CURRENT_TIMESTAMP WHERE id = ?', [status, orderId]);
    res.json({ success: true });
  })
);

module.exports = router;

