#!/usr/bin/env node

require('dotenv').config({ path: require('path').join(__dirname, '..', '.env') });
const db = require('../db');

async function main() {
  console.log('🚚 Backfilling legacy `drivers` table from `users` + `taxis`...');

  // Create table if it doesn't exist (keeps your existing schema if already created).
  await db.query(`
    CREATE TABLE IF NOT EXISTS drivers (
      driver_id INT NOT NULL AUTO_INCREMENT,
      full_name VARCHAR(100) NOT NULL,
      email VARCHAR(250) NOT NULL,
      taxi_matricule VARCHAR(20) NOT NULL,
      phone_number VARCHAR(20) DEFAULT NULL,
      password VARCHAR(255) NOT NULL,
      is_online TINYINT(1) DEFAULT '1',
      last_latitude DECIMAL(10,7) DEFAULT NULL,
      last_longitude DECIMAL(10,7) DEFAULT NULL,
      created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
      updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
      PRIMARY KEY (driver_id),
      UNIQUE KEY taxi_number (taxi_matricule)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci
  `);

  const [result] = await db.query(
    `
    INSERT INTO drivers (full_name, email, taxi_matricule, phone_number, password, is_online, last_latitude, last_longitude)
    SELECT
      u.username as full_name,
      u.email,
      COALESCE(t.license_plate, CONCAT('TX-', LPAD(u.id, 4, '0'))) as taxi_matricule,
      COALESCE(u.phone, t.phone) as phone_number,
      u.password_hash as password,
      COALESCE(t.is_online, 0) as is_online,
      t.lat as last_latitude,
      t.lng as last_longitude
    FROM users u
    LEFT JOIN taxis t ON t.driver_name = u.username
    WHERE u.role = 'driver'
    AS new
    ON DUPLICATE KEY UPDATE
      full_name = new.full_name,
      email = new.email,
      phone_number = new.phone_number,
      password = new.password,
      is_online = new.is_online,
      last_latitude = new.last_latitude,
      last_longitude = new.last_longitude,
      updated_at = CURRENT_TIMESTAMP
    `
  );

  console.log(`✅ Done. Affected rows: ${result.affectedRows}`);
  process.exit(0);
}

main().catch((err) => {
  console.error('❌ Backfill failed:', err);
  process.exit(1);
});

