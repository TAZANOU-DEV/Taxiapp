const mongoose = require('mongoose');

const TaxiSchema = new mongoose.Schema({
  name: String,
  taxId: String,
  isOnline: Boolean,
  lat: Number,
  lng: Number,
});

module.exports = mongoose.model('Taxi', TaxiSchema);
