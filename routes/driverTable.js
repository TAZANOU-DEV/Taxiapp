const express = require('express');
const db = require('../db');

const router = express.Router();

const asyncHandler = (fn) => (req, res, next) =>
  Promise.resolve(fn(req, res, next)).catch(next);

// Legacy `drivers` table API (never returns password).
router.get(
  '/',
  asyncHandler(async (req, res) => {
    const limit = Math.min(parseInt(req.query.limit, 10) || 50, 200);
    const offset = parseInt(req.query.offset, 10) || 0;

    const [drivers] = await db.query(
      `
      SELECT
        driver_id,
        full_name,
        email,
        taxi_matricule,
        phone_number,
        is_online,
        last_latitude,
        last_longitude,
        created_at,
        updated_at
      FROM drivers
      ORDER BY driver_id DESC
      LIMIT ? OFFSET ?
      `,
      [limit, offset]
    );

    res.json({ success: true, drivers });
  })
);

router.get(
  '/:driverId',
  asyncHandler(async (req, res) => {
    const driverId = parseInt(req.params.driverId, 10);
    if (Number.isNaN(driverId)) {
      return res.status(400).json({ error: 'Invalid driverId' });
    }

    const [rows] = await db.query(
      `
      SELECT
        driver_id,
        full_name,
        email,
        taxi_matricule,
        phone_number,
        is_online,
        last_latitude,
        last_longitude,
        created_at,
        updated_at
      FROM drivers
      WHERE driver_id = ?
      LIMIT 1
      `,
      [driverId]
    );

    if (!rows || rows.length === 0) {
      return res.status(404).json({ error: 'Driver not found' });
    }

    res.json({ success: true, driver: rows[0] });
  })
);

module.exports = router;

