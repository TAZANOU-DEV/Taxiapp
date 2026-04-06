#!/usr/bin/env node

/**
 * MySQL Connection Verification Script
 * Tests if MySQL is running and accessible with your configuration
 */

require('dotenv').config();
const mysql = require('mysql2/promise');

const config = {
  host: process.env.DB_HOST || 'localhost',
  user: process.env.DB_USER || 'root',
  password: process.env.DB_PASSWORD || '',
  port: process.env.DB_PORT || 3306,
  database: process.env.DB_NAME || 'taxi_emergency_app'
};

async function testConnection() {
  console.log('\n🧪 MySQL Connection Test');
  console.log('================================\n');

  console.log('📋 Configuration:');
  console.log(`   Host: ${config.host}`);
  console.log(`   Port: ${config.port}`);
  console.log(`   User: ${config.user}`);
  console.log(`   Database: ${config.database}\n`);

  try {
    // Test 1: Connect without specific database
    console.log('1️⃣  Connecting to MySQL server...');
    const testConfig = { ...config };
    delete testConfig.database;
    
    const connection = await mysql.createConnection(testConfig);
    console.log('   ✅ Connected to MySQL server!\n');

    // Test 2: Check if database exists
    console.log('2️⃣  Checking if database exists...');
    const [databases] = await connection.query(
      'SELECT SCHEMA_NAME FROM INFORMATION_SCHEMA.SCHEMATA WHERE SCHEMA_NAME = ?',
      [config.database]
    );

    if (databases.length > 0) {
      console.log(`   ✅ Database "${config.database}" exists!\n`);
    } else {
      console.log(`   ❌ Database "${config.database}" NOT found\n`);
      console.log('   📝 Run this to create it:');
      console.log(`      mysql -u ${config.user} -e "CREATE DATABASE ${config.database};"${config.password ? ` -p${config.password}` : ''}\n`);
    }

    // Test 3: List all tables if database exists
    if (databases.length > 0) {
      console.log('3️⃣  Checking database tables...');
      const poolConfig = { ...config, waitForConnections: true, connectionLimit: 1 };
      const pool = mysql.createPool(poolConfig);
      
      const [tables] = await pool.query('SHOW TABLES');
      
      if (tables.length > 0) {
        console.log(`   ✅ Found ${tables.length} table(s):\n`);
        tables.forEach((table, index) => {
          const tableName = Object.values(table)[0];
          console.log(`      ${index + 1}. ${tableName}`);
        });
        console.log();
      } else {
        console.log('   ⚠️  No tables found in database');
        console.log('   📝 Run: npm run init-db\n');
      }
      
      await pool.end();
    }

    // Test 4: User privileges
    console.log('4️⃣  Checking user privileges...');
    const [grants] = await connection.query('SHOW GRANTS FOR CURRENT_USER()');
    if (grants.length > 0) {
      console.log('   ✅ User privileges:\n');
      grants.forEach(grant => {
        const grantStr = Object.values(grant)[0];
        console.log(`      ${grantStr}`);
      });
      console.log();
    }

    console.log('================================');
    console.log('✅ MySQL Connection Test Passed!\n');
    console.log('Next steps:');
    console.log('  1. Run: npm run init-db');
    console.log('  2. Run: npm run dev\n');

    await connection.end();
    process.exit(0);

  } catch (error) {
    console.log('\n================================');
    console.log('❌ MySQL Connection Test Failed!\n');

    if (error.code === 'PROTOCOL_CONNECTION_LOST') {
      console.log('Error: MySQL server is not running\n');
      console.log('📝 Start MySQL:');
      console.log('   Windows: Open WAMP/XAMPP Control Panel and click Start');
      console.log('   macOS:   brew services start mysql');
      console.log('   Linux:   sudo systemctl start mysql\n');
    } else if (error.code === 'ER_ACCESS_DENIED_FOR_USER') {
      console.log('Error: Wrong MySQL credentials\n');
      console.log('📝 Check your .env file:');
      console.log('   DB_HOST, DB_USER, DB_PASSWORD, DB_PORT\n');
    } else if (error.code === 'ECONNREFUSED') {
      console.log('Error: Cannot connect to MySQL at ' + config.host + ':' + config.port + '\n');
      console.log('📝 Make sure MySQL is running on the correct host and port\n');
    } else {
      console.log(`Error: ${error.message}\n`);
    }

    console.log('📚 For more help, see: Backend/TROUBLESHOOTING.md\n');
    process.exit(1);
  }
}

testConnection();
