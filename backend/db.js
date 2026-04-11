const path = require('path');
require('dotenv').config({ path: path.join(__dirname, '.env') });
const mysql = require('mysql2/promise');

const pool = mysql.createPool({
  host: process.env.DB_HOST || 'localhost',
  user: process.env.DB_USER || 'root',
  password: process.env.DB_PASSWORD || '',
  database: process.env.DB_NAME || 'taxi_emergency_app',
  port: process.env.DB_PORT || 3306,
  waitForConnections: true,
  connectionLimit: 10,
  queueLimit: 0,
  timezone: '+00:00'
});

// Test database connection with retry logic
let connectionAttempts = 0;
const maxAttempts = 5;

const testConnection = () => {
  pool.getConnection()
    .then(connection => {
      console.log('✅ Database connected successfully');
      connection.release();
      connectionAttempts = 0; // Reset on success
    })
    .catch(err => {
      connectionAttempts++;
      console.warn(`⚠️  Database connection attempt ${connectionAttempts}/${maxAttempts} failed:`, err.message);
      
      // Retry connection after 5 seconds
      if (connectionAttempts < maxAttempts) {
        setTimeout(testConnection, 5000);
      } else {
        console.error('❌ Maximum database connection attempts reached. Server running without database.');
        console.error('   Make sure MySQL is running and credentials are correct.');
      }
    });
};

// Test connection on startup
testConnection();

// Optionally test connection periodically
setInterval(() => {
  pool.getConnection()
    .then(connection => {
      connection.release();
    })
    .catch(err => {
      console.warn('⚠️  Database connection lost:', err.message);
    });
}, 30000); // Check every 30 seconds

module.exports = pool;
