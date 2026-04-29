const path = require('path');
require('dotenv').config({ path: path.join(__dirname, '..', '.env') });
const db = require('../db');
const bcrypt = require('bcryptjs');

const initDatabase = async () => {
  try {
    console.log('🚀 Initializing database...');

    // Create database if it doesn't exist
    await db.query(`CREATE DATABASE IF NOT EXISTS ${process.env.DB_NAME}`);
    console.log('✅ Database created or already exists');

    // Use the database
    await db.query(`USE ${process.env.DB_NAME}`);

    // Create taxis table
    await db.query(`
      CREATE TABLE IF NOT EXISTS taxis (
        id INT AUTO_INCREMENT PRIMARY KEY,
        taxi_id VARCHAR(50) UNIQUE NOT NULL,
        lat DECIMAL(10, 8) NOT NULL,
        lng DECIMAL(11, 8) NOT NULL,
        is_online BOOLEAN DEFAULT TRUE,
        vehicle_model VARCHAR(100),
        license_plate VARCHAR(20),
        driver_name VARCHAR(100),
        phone VARCHAR(20),
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
        INDEX idx_location (lat, lng),
        INDEX idx_online (is_online)
      )
    `);
    console.log('✅ Taxis table created');

    // Create activities table
    await db.query(`
      CREATE TABLE IF NOT EXISTS activities (
        id INT AUTO_INCREMENT PRIMARY KEY,
        taxi_id VARCHAR(50) NOT NULL,
        title VARCHAR(255) NOT NULL,
        description TEXT,
        type ENUM('emergency', 'location', 'order', 'status') DEFAULT 'status',
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY (taxi_id) REFERENCES taxis(taxi_id) ON DELETE CASCADE,
        INDEX idx_taxi_time (taxi_id, created_at)
      )
    `);
    console.log('✅ Activities table created');

    // Create taxi_orders table
    await db.query(`
      CREATE TABLE IF NOT EXISTS taxi_orders (
        id INT AUTO_INCREMENT PRIMARY KEY,
        from_taxi_id VARCHAR(50) NOT NULL,
        to_taxi_id VARCHAR(50) NOT NULL,
        status ENUM('requested', 'accepted', 'on_way', 'arrived', 'completed', 'cancelled') DEFAULT 'requested',
        pickup_lat DECIMAL(10, 8),
        pickup_lng DECIMAL(11, 8),
        dropoff_lat DECIMAL(10, 8),
        dropoff_lng DECIMAL(11, 8),
        reason VARCHAR(255),
        fare DECIMAL(10, 2),
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
        FOREIGN KEY (from_taxi_id) REFERENCES taxis(taxi_id) ON DELETE CASCADE,
        FOREIGN KEY (to_taxi_id) REFERENCES taxis(taxi_id) ON DELETE CASCADE,
        INDEX idx_status (status),
        INDEX idx_created (created_at)
      )
    `);
    console.log('✅ Taxi orders table created');

    // Create users table
    await db.query(`
      CREATE TABLE IF NOT EXISTS users (
        id INT AUTO_INCREMENT PRIMARY KEY,
        username VARCHAR(50) UNIQUE NOT NULL,
        email VARCHAR(100) UNIQUE NOT NULL,
        password_hash VARCHAR(255) NOT NULL,
        role ENUM('admin', 'driver') DEFAULT 'driver',
        provider VARCHAR(50) DEFAULT NULL,
        provider_id VARCHAR(255) DEFAULT NULL,
        reset_token VARCHAR(255) DEFAULT NULL,
        reset_token_expires DATETIME DEFAULT NULL,
        is_active BOOLEAN DEFAULT TRUE,
        phone VARCHAR(20),
        profile_image VARCHAR(255),
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
        INDEX idx_email (email),
        INDEX idx_username (username),
        INDEX idx_provider (provider),
        INDEX idx_provider_id (provider_id)
      )
    `);
    console.log('✅ Users table created');

    // Create legacy drivers table (optional compatibility; some setups use it separately from `users`)
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
      )
    `);
    console.log('✅ Drivers table created');

    // Create legacy emergency alerts table (driver-centric)
    await db.query(`
      CREATE TABLE IF NOT EXISTS emergency_alerts (
        alert_id INT NOT NULL AUTO_INCREMENT,
        driver_id INT NOT NULL,
        latitude DECIMAL(10,7) DEFAULT NULL,
        longitude DECIMAL(10,7) DEFAULT NULL,
        status ENUM('pending','resolved') DEFAULT 'pending',
        created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
        PRIMARY KEY (alert_id),
        INDEX idx_driver (driver_id),
        INDEX idx_status (status)
      )
    `);

    // Create legacy activity table (driver-centric)
    await db.query(`
      CREATE TABLE IF NOT EXISTS activity (
        activity_id INT NOT NULL AUTO_INCREMENT,
        driver_id INT NOT NULL,
        action VARCHAR(255) NOT NULL,
        timestamp DATETIME DEFAULT CURRENT_TIMESTAMP,
        PRIMARY KEY (activity_id),
        INDEX idx_driver (driver_id)
      )
    `);

    // Add profile_image column if it doesn't exist (for existing databases)
    try {
      await db.query(`ALTER TABLE users ADD COLUMN IF NOT EXISTS profile_image VARCHAR(255)`);
      console.log('✅ Profile image column added');
    } catch (error) {
      console.log('Profile image column already exists or error:', error.message);
    }

    // Insert sample users
    console.log('👤 Creating sample users...');

    const sampleUsers = [
      {
        username: 'admin',
        email: 'admin@taxiapp.com',
        password: 'admin123',
        role: 'admin',
        phone: '+237600000000'
      },
      {
        username: 'driver1',
        email: 'driver1@taxiapp.com',
        password: 'driver123',
        role: 'driver',
        phone: '+237612345678'
      },
      {
        username: 'driver2',
        email: 'driver2@taxiapp.com',
        password: 'driver123',
        role: 'driver',
        phone: '+237623456789'
      }
    ];

    for (const user of sampleUsers) {
      const saltRounds = 10;
      const passwordHash = await bcrypt.hash(user.password, saltRounds);

      await db.query(
        'INSERT INTO users (username, email, password_hash, role, phone) VALUES (?, ?, ?, ?, ?) ON DUPLICATE KEY UPDATE username = username',
        [user.username, user.email, passwordHash, user.role, user.phone]
      );
    }

    console.log('✅ Sample users created');

    // Sample taxis
    const sampleTaxis = [
      ['CM-TX-001', 3.8667, 11.5167, 'Toyota Camry', 'ABC-123', 'John Doe', '+237612345678'],
      ['CM-TX-002', 3.8677, 11.5177, 'Honda Civic', 'DEF-456', 'Jane Smith', '+237623456789'],
      ['CM-TX-003', 3.8657, 11.5157, 'Ford Focus', 'GHI-789', 'Bob Johnson', '+237634567890'],
    ];

    for (const taxi of sampleTaxis) {
      await db.query(`
        INSERT INTO taxis (taxi_id, lat, lng, vehicle_model, license_plate, driver_name, phone)
        VALUES (?, ?, ?, ?, ?, ?, ?)
        ON DUPLICATE KEY UPDATE
          lat = VALUES(lat),
          lng = VALUES(lng),
          vehicle_model = VALUES(vehicle_model),
          license_plate = VALUES(license_plate),
          driver_name = VALUES(driver_name),
          phone = VALUES(phone)
      `, taxi);
    }

    console.log('✅ Sample data inserted');
    console.log('🎉 Database initialization completed successfully!');

  } catch (error) {
    console.error('❌ Database initialization failed:', error);
    process.exit(1);
  } finally {
    process.exit(0);
  }
};

initDatabase();
