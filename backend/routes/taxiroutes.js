
const express = require('express');
const router = express.Router();
const db = require('../db');

module.exports = (io) => {
const asyncHandler = (fn) => (req, res, next) => {
  Promise.resolve(fn(req, res, next)).catch(next);
};

// 📍 Share Location
router.post('/location', asyncHandler(async (req, res) => {
  const { taxiId, lat, lng } = req.body;

  if (!taxiId || !lat || !lng) {
    return res.status(400).json({ error: 'Missing required fields: taxiId, lat, lng' });
  }

  const sql = `
    INSERT INTO taxis (taxi_id, lat, lng, is_online)
    VALUES (?, ?, ?, true)
    ON DUPLICATE KEY UPDATE
      lat = VALUES(lat),
      lng = VALUES(lng),
      is_online = true,
      updated_at = CURRENT_TIMESTAMP
  `;

  await db.query(sql, [taxiId, lat, lng]);

  // Log activity
  await db.query(
    'INSERT INTO activities (taxi_id, title, type) VALUES (?, ?, ?)',
    [taxiId, '📍 Location shared', 'location']
  );

  res.json({ success: true, message: 'Location shared successfully' });
}));

// 🚨 Emergency Alert
router.post('/emergency', asyncHandler(async (req, res) => {
  const { taxiId, lat, lng, message = 'Emergency alert sent' } = req.body;

  if (!taxiId) {
    return res.status(400).json({ error: 'Missing required field: taxiId' });
  }

  // Get taxi details
  const [taxiResults] = await db.query(
    'SELECT license_plate, driver_name, phone FROM taxis WHERE taxi_id = ?',
    [taxiId]
  );

  const taxiInfo = taxiResults[0] || {};

  // Log activity
  await db.query(
    'INSERT INTO activities (taxi_id, title, description, type) VALUES (?, ?, ?, ?)',
    [taxiId, '🚨 Emergency alert sent', message, 'emergency']
  );

  // Broadcast to all connected taxis
  io.emit('emergencyAlert', {
    taxiId,
    taxiNumber: taxiInfo.license_plate || taxiId,
    driverName: taxiInfo.driver_name || 'Unknown',
    phone: taxiInfo.phone || '',
    lat: lat || null,
    lng: lng || null,
    message,
    timestamp: new Date().toISOString()
  });

  // TODO: Send to police (e.g., via SMS/email API)

  res.json({ success: true, message: 'Emergency alert sent to all taxis' });
}));

// 📜 Get Activity History
router.get('/activities/:taxiId', asyncHandler(async (req, res) => {
  const taxiId = req.params.taxiId;
  const limit = parseInt(req.query.limit) || 50;
  const offset = parseInt(req.query.offset) || 0;

  const [results] = await db.query(
    'SELECT * FROM activities WHERE taxi_id = ? ORDER BY created_at DESC LIMIT ? OFFSET ?',
    [taxiId, limit, offset]
  );

  res.json(results || []);
}));

// 🚕 Get Nearby Taxis (within radius)
router.get('/nearby', asyncHandler(async (req, res) => {
  const { lat, lng, radius = 5 } = req.query;

  if (!lat || !lng) {
    return res.status(400).json({ error: 'Missing required query parameters: lat, lng' });
  }

  const latNum = parseFloat(lat);
  const lngNum = parseFloat(lng);
  const radiusNum = parseFloat(radius);

  // Haversine formula for distance calculation
  const sql = `
    SELECT
      taxi_id,
      lat,
      lng,
      is_online,
      vehicle_model,
      license_plate,
      driver_name,
      phone,
      created_at,
      updated_at,
      (
        6371 * acos(
          cos(radians(?)) * cos(radians(lat)) * cos(radians(lng) - radians(?)) +
          sin(radians(?)) * sin(radians(lat))
        )
      ) AS distance_km
    FROM taxis
    WHERE is_online = true
    HAVING distance_km <= ?
    ORDER BY distance_km ASC
  `;

  const [results] = await db.query(sql, [latNum, lngNum, latNum, radiusNum]);

  res.json(results || []);
}));

// 📋 Create Taxi Order
router.post('/order', asyncHandler(async (req, res) => {
  const { from_taxi_id, to_taxi_id, pickup_lat, pickup_lng, dropoff_lat, dropoff_lng, reason = 'assistance' } = req.body;

  if (!from_taxi_id || !to_taxi_id) {
    return res.status(400).json({ error: 'Missing required fields: from_taxi_id, to_taxi_id' });
  }

  const sql = `
    INSERT INTO taxi_orders (from_taxi_id, to_taxi_id, status, pickup_lat, pickup_lng, dropoff_lat, dropoff_lng, reason)
    VALUES (?, ?, 'requested', ?, ?, ?, ?, ?)
  `;

  const [result] = await db.query(sql, [from_taxi_id, to_taxi_id, pickup_lat, pickup_lng, dropoff_lat, dropoff_lng, reason]);

  res.json({
    success: true,
    orderId: result.insertId,
    message: 'Order created successfully'
  });
}));

// 📬 Get Active Orders for Taxi
router.get('/orders/:taxiId', asyncHandler(async (req, res) => {
  const taxiId = req.params.taxiId;
  const status = req.query.status; // Optional filter

  let sql = `
    SELECT * FROM taxi_orders
    WHERE (from_taxi_id = ? OR to_taxi_id = ?)
  `;
  let params = [taxiId, taxiId];

  if (status) {
    sql += ' AND status = ?';
    params.push(status);
  }

  sql += ' ORDER BY created_at DESC';

  const [results] = await db.query(sql, params);

  res.json(results || []);
}));

// ✅ Update Order Status
router.put('/order/:orderId', asyncHandler(async (req, res) => {
  const { orderId } = req.params;
  const { status, fare } = req.body;

  if (!status) {
    return res.status(400).json({ error: 'Missing required field: status' });
  }

  const validStatuses = ['requested', 'accepted', 'on_way', 'arrived', 'completed', 'cancelled'];
  if (!validStatuses.includes(status)) {
    return res.status(400).json({ error: 'Invalid status value' });
  }

  let sql = 'UPDATE taxi_orders SET status = ?, updated_at = CURRENT_TIMESTAMP';
  let params = [status];

  if (fare !== undefined) {
    sql += ', fare = ?';
    params.push(fare);
  }

  sql += ' WHERE id = ?';
  params.push(orderId);

  const [result] = await db.query(sql, params);

  if (result.affectedRows === 0) {
    return res.status(404).json({ error: 'Order not found' });
  }

  res.json({ success: true, message: 'Order updated successfully' });
}));

// 👤 Get Taxi Profile
router.get('/profile/:taxiId', asyncHandler(async (req, res) => {
  const taxiId = req.params.taxiId;

  const [results] = await db.query(
    'SELECT taxi_id, lat, lng, is_online, vehicle_model, license_plate, driver_name, phone, created_at, updated_at FROM taxis WHERE taxi_id = ?',
    [taxiId]
  );

  if (results.length === 0) {
    return res.status(404).json({ error: 'Taxi not found' });
  }

  res.json(results[0]);
}));

// 📊 Get Dashboard Stats
router.get('/stats', asyncHandler(async (req, res) => {
  const [onlineTaxis] = await db.query('SELECT COUNT(*) as count FROM taxis WHERE is_online = true');
  const [totalOrders] = await db.query('SELECT COUNT(*) as count FROM taxi_orders');
  const [activeOrders] = await db.query("SELECT COUNT(*) as count FROM taxi_orders WHERE status IN ('requested', 'accepted', 'on_way')");
  const [emergencyCount] = await db.query("SELECT COUNT(*) as count FROM activities WHERE type = 'emergency' AND DATE(created_at) = CURDATE()");

  res.json({
    onlineTaxis: onlineTaxis[0].count,
    totalOrders: totalOrders[0].count,
    activeOrders: activeOrders[0].count,
    todayEmergencies: emergencyCount[0].count
  });
}));

  return router;
};
