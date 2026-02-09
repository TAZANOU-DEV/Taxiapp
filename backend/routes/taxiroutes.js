const express = require('express');
const router = express.Router();
const Taxi = require('../models/Taxi');
const Activity = require('../models/Activity');

/// 📍 Share Location
router.post('/location', async (req, res) => {
  const { taxiId, lat, lng } = req.body;

  await Taxi.findOneAndUpdate(
    { taxId: taxiId },
    { lat, lng, isOnline: true },
    { upsert: true }
  );

  await Activity.create({
    taxiId,
    title: "📍 Location shared",
    time: "Just now",
  });

  res.json({ success: true });
});

/// 🚨 Emergency Alert
router.post('/emergency', async (req, res) => {
  const { taxiId } = req.body;

  await Activity.create({
    taxiId,
    title: "🚨 Emergency alert sent",
    time: "Just now",
  });

  res.json({ message: "Emergency sent" });
});

/// 📜 Activity History
router.get('/activities/:taxiId', async (req, res) => {
  const activities = await Activity.find({
    taxiId: req.params.taxiId,
  }).sort({ _id: -1 });

  res.json(activities);
});

/// 👥 Nearby Taxmen
router.get('/nearby', async (req, res) => {
  const { lat, lng } = req.query;

  const taxis = await Taxi.find({ isOnline: true });

  const nearby = taxis.filter(t => {
    const dx = lat - t.lat;
    const dy = lng - t.lng;
    return Math.sqrt(dx * dx + dy * dy) < 0.05;
  });

  res.json(nearby);
});

module.exports = router;
