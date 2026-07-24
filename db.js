const path = require('path');
require('dotenv').config({ path: path.join(__dirname, '.env') });
const mysql = require('mysql2/promise');

const databaseName = process.env.DB_NAME || 'taxi_emergency_app';

const poolConfig = {
  host: process.env.DB_HOST || 'localhost',
  user: process.env.DB_USER || 'root',
  password: process.env.DB_PASSWORD || '',
  database: databaseName,
  port: Number(process.env.DB_PORT) || 4000,
  waitForConnections: true,
  connectionLimit: 5,            // Réduit pour limiter la charge en Serverless
  maxIdle: 2,                    // Libère les connexions inactives
  idleTimeout: 30000,            // Ferme les connexions inactives après 30s
  enableKeepAlive: true,         // Evite que TiDB ferme la connexion prématurément
  keepAliveInitialDelay: 10000,  // Ping toutes les 10 secondes
  queueLimit: 0,
  timezone: '+00:00',
};

// Configuration SSL automatique pour TiDB Cloud
if (process.env.DB_SSL === 'true' || process.env.DB_HOST?.includes('tidbcloud.com')) {
  poolConfig.ssl = {
    minVersion: process.env.DB_SSL_MIN_VERSION || 'TLSv1.2',
    rejectUnauthorized: process.env.DB_SSL_REJECT_UNAUTHORIZED !== 'false',
  };
}

const pool = mysql.createPool(poolConfig);

const ensureDatabase = async () => {
  try {
    const [rows] = await pool.query('SELECT DATABASE() AS current_db');
    const currentDb = rows?.[0]?.current_db;

    if (currentDb !== databaseName) {
      await pool.query(`USE \`${databaseName}\``);
    }

    console.log(`✅ Database selected: ${databaseName}`);
  } catch (err) {
    console.warn('⚠️ Could not ensure database selection:', err.message);
  }
};

// Test initial de connexion au démarrage
const testConnection = async () => {
  try {
    const connection = await pool.getConnection();
    console.log('✅ Database connected successfully');
    await ensureDatabase();
    connection.release();
  } catch (err) {
    console.error('❌ Database connection failed:', err.message);
  }
};

testConnection();

module.exports = pool;