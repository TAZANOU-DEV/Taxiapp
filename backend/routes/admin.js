const express = require('express');
const db = require('../db');

const router = express.Router();

// Middleware to check admin role
const requireAdmin = (req, res, next) => {
  if (req.user.role !== 'admin') {
    return res.status(403).json({ error: 'Admin access required' });
  }
  next();
};

// Get all taxis
router.get('/taxis', async (req, res) => {
  try {
    const [taxis] = await db.query(`
      SELECT
        t.*,
        COUNT(o.id) as total_orders,
        COUNT(CASE WHEN o.status = 'completed' THEN 1 END) as completed_orders
      FROM taxis t
      LEFT JOIN taxi_orders o ON t.taxi_id = o.to_taxi_id
      GROUP BY t.taxi_id
      ORDER BY t.created_at DESC
    `);

    res.json({ success: true, taxis });
  } catch (error) {
    console.error('Error fetching taxis:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// Get all orders
router.get('/orders', async (req, res) => {
  try {
    const status = req.query.status;
    const limit = parseInt(req.query.limit) || 50;
    const offset = parseInt(req.query.offset) || 0;

    let sql = `
      SELECT
        o.*,
        t_from.driver_name as from_driver,
        t_to.driver_name as to_driver
      FROM taxi_orders o
      LEFT JOIN taxis t_from ON o.from_taxi_id = t_from.taxi_id
      LEFT JOIN taxis t_to ON o.to_taxi_id = t_to.taxi_id
    `;

    const params = [];

    if (status) {
      sql += ' WHERE o.status = ?';
      params.push(status);
    }

    sql += ' ORDER BY o.created_at DESC LIMIT ? OFFSET ?';
    params.push(limit, offset);

    const [orders] = await db.query(sql, params);

    res.json({ success: true, orders });
  } catch (error) {
    console.error('Error fetching orders:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// Get system statistics
router.get('/stats', async (req, res) => {
  try {
    const [stats] = await db.query(`
      SELECT
        (SELECT COUNT(*) FROM taxis WHERE is_online = true) as online_taxis,
        (SELECT COUNT(*) FROM taxis) as total_taxis,
        (SELECT COUNT(*) FROM taxi_orders) as total_orders,
        (SELECT COUNT(*) FROM taxi_orders WHERE status = 'completed') as completed_orders,
        (SELECT COUNT(*) FROM taxi_orders WHERE status IN ('requested', 'accepted', 'on_way')) as active_orders,
        (SELECT COUNT(*) FROM activities WHERE type = 'emergency' AND DATE(created_at) = CURDATE()) as today_emergencies,
        (SELECT COUNT(*) FROM users WHERE role = 'driver') as total_drivers,
        (SELECT COUNT(*) FROM users WHERE role = 'admin') as total_admins
    `);

    res.json({ success: true, stats: stats[0] });
  } catch (error) {
    console.error('Error fetching stats:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// Get emergency alerts
router.get('/emergencies', async (req, res) => {
  try {
    const limit = parseInt(req.query.limit) || 20;
    const [emergencies] = await db.query(`
      SELECT
        a.*,
        t.driver_name,
        t.phone,
        t.lat,
        t.lng
      FROM activities a
      LEFT JOIN taxis t ON a.taxi_id = t.taxi_id
      WHERE a.type = 'emergency'
      ORDER BY a.created_at DESC
      LIMIT ?
    `, [limit]);

    res.json({ success: true, emergencies });
  } catch (error) {
    console.error('Error fetching emergencies:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// Update taxi status (admin only)
router.put('/taxi/:taxiId/status', async (req, res) => {
  try {
    const { taxiId } = req.params;
    const { isOnline } = req.body;

    await db.query(
      'UPDATE taxis SET is_online = ?, updated_at = CURRENT_TIMESTAMP WHERE taxi_id = ?',
      [isOnline, taxiId]
    );

    res.json({ success: true, message: 'Taxi status updated' });
  } catch (error) {
    console.error('Error updating taxi status:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// Get activity logs
router.get('/activities', async (req, res) => {
  try {
    const limit = parseInt(req.query.limit) || 100;
    const type = req.query.type;

    let sql = `
      SELECT
        a.*,
        t.driver_name
      FROM activities a
      LEFT JOIN taxis t ON a.taxi_id = t.taxi_id
    `;

    const params = [];

    if (type) {
      sql += ' WHERE a.type = ?';
      params.push(type);
    }

    sql += ' ORDER BY a.created_at DESC LIMIT ?';
    params.push(limit);

    const [activities] = await db.query(sql, params);

    res.json({ success: true, activities });
  } catch (error) {
    console.error('Error fetching activities:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

module.exports = router;