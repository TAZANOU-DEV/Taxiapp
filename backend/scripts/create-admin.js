const path = require('path');
require('dotenv').config({ path: path.join(__dirname, '..', '.env') });
const db = require('../db');
const bcrypt = require('bcryptjs');

const createAdminUser = async () => {
  try {
    const username = 'admin';
    const email = 'admin@gmail.com';
    const password = 'zxcvbnm+';
    const role = 'admin';

    const normalizedEmail = email.trim().toLowerCase();
    const normalizedUsername = username.trim();

    const saltRounds = 10;
    const passwordHash = await bcrypt.hash(password, saltRounds);

    const [existingUsers] = await db.query(
      'SELECT id, email, username FROM users WHERE email = ? OR username = ?',
      [normalizedEmail, normalizedUsername]
    );

    if (existingUsers.length > 0) {
      const user = existingUsers[0];
      await db.query(
        'UPDATE users SET username = ?, email = ?, password_hash = ?, role = ? WHERE id = ?',
        [normalizedUsername, normalizedEmail, passwordHash, role, user.id]
      );
      console.log(`✅ Updated existing admin user with id=${user.id}`);
    } else {
      const [result] = await db.query(
        'INSERT INTO users (username, email, password_hash, role) VALUES (?, ?, ?, ?)',
        [normalizedUsername, normalizedEmail, passwordHash, role]
      );
      console.log(`✅ Created admin user with id=${result.insertId}`);
    }

    console.log('Admin account is ready:');
    console.log(`  username: ${normalizedUsername}`);
    console.log(`  email: ${normalizedEmail}`);
    console.log(`  password: ${password}`);
  } catch (error) {
    console.error('❌ Failed to create admin user:', error.message);
    process.exit(1);
  } finally {
    process.exit(0);
  }
};

createAdminUser();
