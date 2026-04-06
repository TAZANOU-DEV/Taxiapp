# MySQL Setup & Usage Guide

## 🎯 Overview

Your Taxi App uses **MySQL** as the primary database. This guide walks you through installing, configuring, and using MySQL.

---

## 📋 Prerequisites

- **MySQL Server**: v5.7 or higher
- **Node.js**: v16 or higher
- **npm**: v7 or higher

---

## 🚀 Installation

### **Windows**

#### Option 1: Using MySQL Installer (Recommended)
1. Download from: https://dev.mysql.com/downloads/mysql/
2. Run the installer and follow the wizard
3. Choose "Server only" or "Full"
4. Port: **3306** (default)
5. Username: **root** (default)
6. Password: Leave empty or set one

#### Option 2: Using WAMP Stack (Easy)
1. Download WAMP from: http://www.wampserver.com/
2. Install and run
3. MySQL comes pre-installed with WAMP
4. Default credentials:
   - Username: `root`
   - Password: (empty)

#### Option 3: Using XAMPP
1. Download XAMPP from: https://www.apachefriends.org/
2. Install and run XAMPP Control Panel
3. Click "Start" next to MySQL
4. Default credentials:
   - Username: `root`
   - Password: (empty)

### **macOS**

```bash
# Install using Homebrew
brew install mysql

# Start MySQL
brew services start mysql

# Verify installation
mysql --version
```

### **Linux (Ubuntu/Debian)**

```bash
# Install MySQL
sudo apt-get update
sudo apt-get install mysql-server

# Start MySQL
sudo systemctl start mysql

# Verify installation
mysql --version
```

### **Linux (CentOS/RHEL)**

```bash
# Install MySQL
sudo yum install mysql-server

# Start MySQL
sudo systemctl start mysqld

# Verify installation
mysql --version
```

---

## ⚙️ Configuration

### **1. Check Current Configuration**

View your `.env` file:

```bash
# File location:
Backend/.env
```

Default configuration:
```env
DB_HOST=localhost
DB_USER=root
DB_PASSWORD=
DB_NAME=taxi_emergency_app
DB_PORT=3306
```

### **2. Update Credentials (if needed)**

If you set a MySQL password during installation:

```env
DB_HOST=localhost
DB_USER=root
DB_PASSWORD=your_mysql_password
DB_NAME=taxi_emergency_app
DB_PORT=3306
```

### **3. Verify Connection**

Test if MySQL is accessible:

```bash
mysql -h localhost -u root -p
```

If no password, just press Enter when prompted.

You should see:
```
MySQL [your_version]
Type 'help;' or '\h' for help.

mysql>
```

Type `EXIT;` to quit.

---

## 🏗️ Database Setup

### **Step 1: Test MySQL Connection**

```bash
cd Backend
npm run test-mysql
```

This will:
- ✅ Test MySQL connection
- ✅ Check if database exists
- ✅ List tables if database exists
- ✅ Check user privileges

### **Step 2: Initialize Database**

```bash
npm run init-db
```

This will:
- ✅ Create database if not exists
- ✅ Create all required tables:
  - `users` - User accounts and authentication
  - `taxis` - Taxi/driver information
  - `taxi_orders` - Service orders
  - `activities` - Activity logging
- ✅ Insert sample data and users

### **Step 3: Verify Setup**

Connect to the database and check tables:

```bash
mysql -h localhost -u root taxi_emergency_app
SHOW TABLES;
```

You should see:
```
+----------------------------+
| Tables_in_taxi_emergency_app |
+----------------------------+
| activities                 |
| taxis                      |
| taxi_orders                |
| users                       |
+----------------------------+
```

---

## 💾 Database Schema Overview

### **users Table**
Stores user accounts and authentication:
```sql
- id: Auto-increment primary key
- username: Unique username
- email: Unique email
- password_hash: Bcrypt hashed password
- role: 'admin' or 'driver'
- is_active: Account status
- created_at: Creation timestamp
```

### **taxis Table**
Stores taxi/driver information:
```sql
- id: Auto-increment primary key
- taxi_id: Unique taxi identifier
- lat: Latitude (location)
- lng: Longitude (location)
- is_online: Online status
- vehicle_model: Vehicle type
- license_plate: License plate number
- driver_name: Driver name
- phone: Driver phone
- created_at: Creation timestamp
```

### **taxi_orders Table**
Stores service orders:
```sql
- id: Auto-increment primary key
- from_taxi_id: Requesting taxi
- to_taxi_id: Target taxi
- status: 'requested', 'accepted', 'on_way', 'arrived', 'completed'
- pickup_lat, pickup_lng: Pickup location
- dropoff_lat, dropoff_lng: Dropoff location
- fare: Fare amount
- created_at: Order creation timestamp
```

### **activities Table**
Stores activity logs:
```sql
- id: Auto-increment primary key
- taxi_id: Associated taxi
- title: Activity title
- description: Detailed description
- type: 'emergency', 'location', 'order', 'status'
- created_at: Activity timestamp
```

---

## 🔧 Common MySQL Commands

### **Connection**
```bash
# Connect to MySQL
mysql -h localhost -u root -p

# Connect to specific database
mysql -h localhost -u root -p taxi_emergency_app

# Execute SQL file
mysql -u root -p taxi_emergency_app < script.sql
```

### **Database Operations**
```sql
-- Show all databases
SHOW DATABASES;

-- Create database
CREATE DATABASE taxi_emergency_app;

-- Use database
USE taxi_emergency_app;

-- Delete database
DROP DATABASE taxi_emergency_app;
```

### **Table Operations**
```sql
-- Show tables
SHOW TABLES;

-- Show table structure
DESCRIBE table_name;
-- or
SHOW COLUMNS FROM table_name;

-- Show table data
SELECT * FROM table_name;

-- Count rows
SELECT COUNT(*) FROM table_name;
```

### **User Management**
```sql
-- Create new MySQL user
CREATE USER 'username'@'localhost' IDENTIFIED BY 'password';

-- Grant privileges
GRANT ALL PRIVILEGES ON taxi_emergency_app.* TO 'username'@'localhost';
FLUSH PRIVILEGES;

-- Show current user
SELECT USER();

-- Show user privileges
SHOW GRANTS FOR CURRENT_USER();
```

---

## 🚀 Running the Application

### **Step 1: Start MySQL**

**Windows (WAMP):**
- Open WAMP Control Panel
- Click "Start All"

**Windows (MySQL Service):**
- Open `services.msc`
- Find "MySQL80"
- Right-click → Start

**macOS:**
```bash
brew services start mysql
```

**Linux:**
```bash
sudo systemctl start mysql
```

### **Step 2: Verify MySQL is Running**

```bash
cd Backend
npm run test-mysql
```

You should see: ✅ MySQL Connection Test Passed!

### **Step 3: Start Backend Server**

```bash
npm run dev
```

You should see:
```
🚀 Backend server running on port 3000
🌍 Environment: development
✅ Database connected successfully
```

### **Step 4: Start Flutter Frontend**

In a new terminal:
```bash
cd ..
flutter run
```

---

## 🔒 Security Practices

### **Production Setup**

1. **Change Root Password**
   ```bash
   # Windows
   mysqladmin -u root password "new_strong_password"
   
   # macOS/Linux
   sudo mysql -u root -e "ALTER USER 'root'@'localhost' IDENTIFIED BY 'strong_password';"
   ```

2. **Create App User (Not Root)**
   ```sql
   CREATE USER 'taxi_app'@'localhost' IDENTIFIED BY 'app_password';
   GRANT ALL PRIVILEGES ON taxi_emergency_app.* TO 'taxi_app'@'localhost';
   FLUSH PRIVILEGES;
   ```

3. **Update .env**
   ```env
   DB_USER=taxi_app
   DB_PASSWORD=app_password
   ```

4. **Enable SSL**
   - Use SSL connections in production
   - Update connection config with SSL certificates

5. **Regular Backups**
   ```bash
   # Backup database
   mysqldump -u root -p taxi_emergency_app > backup.sql
   
   # Restore database
   mysql -u root -p taxi_emergency_app < backup.sql
   ```

---

## 📊 Backup & Restore

### **Backup Database**

```bash
# Full backup
mysqldump -u root -p taxi_emergency_app > backup.sql

# Backup all databases
mysqldump -u root -p --all-databases > full_backup.sql

# Compressed backup
mysqldump -u root -p taxi_emergency_app | gzip > backup.sql.gz
```

### **Restore Database**

```bash
# Restore from backup
mysql -u root -p taxi_emergency_app < backup.sql

# Restore compressed backup
gunzip < backup.sql.gz | mysql -u root -p taxi_emergency_app
```

---

## 🧪 Testing Queries

### **Sample Data**

After running `npm run init-db`, you have sample data:

```sql
-- View sample users
SELECT * FROM users;
-- Result: admin, driver1, driver2 accounts

-- View sample taxis
SELECT * FROM taxis;

-- View all orders
SELECT * FROM taxi_orders;

-- View user activities
SELECT * FROM activities;
```

### **Common Test Queries**

```sql
-- Find taxis within 5km radius
SELECT * FROM taxis WHERE is_online = true;

-- Get user by email
SELECT * FROM users WHERE email = 'admin@taxiapp.com';

-- Get active orders
SELECT * FROM taxi_orders WHERE status IN ('requested', 'accepted', 'on_way');

-- Get today's activities
SELECT * FROM activities WHERE DATE(created_at) = CURDATE();

-- Count statistics
SELECT COUNT(*) as total_taxis FROM taxis WHERE is_online = true;
SELECT COUNT(*) as total_orders FROM taxi_orders;
SELECT COUNT(*) as total_users FROM users;
```

---

## ⚠️ Troubleshooting

### **MySQL Won't Start**

**Windows:**
1. Open Services (services.msc)
2. Right-click MySQL service
3. Properties → Recovery
4. Set restart options
5. Try starting again

**macOS/Linux:**
```bash
# Check if MySQL is running
ps aux | grep mysql

# Check MySQL logs
tail -f /var/log/mysql/error.log

# Try restarting
sudo systemctl restart mysql
```

### **Connection Refused**

```bash
# Test connection
mysql -h localhost -u root -p

# If fails, check if MySQL is running
ps aux | grep [m]ysqld

# Restart MySQL
sudo systemctl restart mysql
```

### **Access Denied**

```bash
# Check user/password
mysql -h localhost -u root -p

# Enter password when prompted
# If still fails, reset MySQL password:
sudo mysqld_safe --skip-grant-tables &
mysql -u root
FLUSH PRIVILEGES;
ALTER USER 'root'@'localhost' IDENTIFIED BY 'new_password';
EXIT;
```

### **Database Not Found**

```bash
# Create database
mysql -u root -p -e "CREATE DATABASE taxi_emergency_app;"

# Initialize
npm run init-db
```

---

## 📚 Resources

- [MySQL Official Documentation](https://dev.mysql.com/doc/)
- [MySQL Workbench](https://www.mysql.com/products/workbench/) - GUI tool
- [DBeaver](https://dbeaver.io/) - Cross-platform database tool
- [Sequel Pro](https://www.sequelpro.com/) - macOS only

---

## ✅ Checklist

- [ ] MySQL is installed
- [ ] MySQL service is running
- [ ] Can connect with `mysql -u root -p`
- [ ] `.env` file has correct credentials
- [ ] `npm run test-mysql` passes
- [ ] Database `taxi_emergency_app` exists
- [ ] All tables are created
- [ ] Sample data is loaded
- [ ] Backend starts with `npm run dev`
- [ ] Frontend connects to backend

---

## 🎉 You're Ready!

Your MySQL database is now fully configured and your app is ready to run with a professional-grade database backend.

**Next steps:**
1. Run `npm run dev` to start the backend
2. Run `flutter run` to start the frontend
3. Login with sample credentials (see `Backend/README.md`)
4. Enjoy building your taxi app!
