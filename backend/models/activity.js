const mongoose = require('mongoose');

const ActivitySchema = new mongoose.Schema({
  taxiId: String,
  title: String,
  time: String,
});

module.exports = mongoose.model('Activity', ActivitySchema);
