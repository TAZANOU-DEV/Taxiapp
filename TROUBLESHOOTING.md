# Backend Server Troubleshooting Guide

## Issue: "[nodemon] app crashed - waiting for file changes before starting..."

This error occurs when the Node.js server crashes during startup. Here are the common causes and solutions:

---

## ✅ **Solution 1: Start MySQL Server** (Most Common)

The primary issue is that MySQL is not running on your machine.

### **On Windows:**

#### Option A: Start MySQL using Windows Services
1. Press `Windows + R`
2. Type `services.msc` and press Enter
3. Look for **"MySQL80"** or **"MySQL"** in the list
4. Right-click and select **"Start"**
5. Wait for the status to show "Running"

#### Option B: Start MySQL from Command Line
```bash
# For MySQL 8.0 installed via MySQL installer
"C:\Program Files\MySQL\MySQL Server 8.0\bin\mysqld.exe"

# Or if MySQL is in a different location, try:
mysqld
```

#### Option C: Use WAMP/XAMPP (if installed)
1. Open WAMP Control Panel or XAMPP Control Panel
2. Click **"Start All"** or start Apache and MySQL individually
3. Ensure MySQL shows as "Running" (green indicator)

### **On macOS:**
```bash
# Start MySQL using Homebrew
brew services start mysql

# Or if using MySQL installer
sudo /usr/local/mysql/support-files/mysql.server start
```

### **On Linux:**
```bash
# Using systemctl
sudo systemctl start mysql

# Or
sudo service mysql start
```

---

## ✅ **Solution 2: Verify MySQL Credentials**

Check if your `.env` file has the correct credentials:

```bash
# In Backend/.env, verify:
DB_HOST=localhost
DB_USER=root
DB_PASSWORD=          # Leave empty if you didn't set a password
DB_NAME=taxi_emergency_app
DB_PORT=3306
```

Test MySQL connection:
```bash
# From command line
mysql -h localhost -u root -p

# If password is blank, just press Enter
```

---

## ✅ **Solution 3: Create the Database**

If MySQL is running but the database doesn't exist, create it:

```bash
# Connect to MySQL
mysql -h localhost -u root -p

# Then run:
CREATE DATABASE taxi_emergency_app;
EXIT;
```

---

## ✅ **Solution 4: Run Database Initialization Script**

After ensuring MySQL is running and the database exists:

```bash
cd Backend
npm run init-db
```

This will create all required tables and sample data.

---

## ✅ **Solution 5: Start the Server**

After resolving the above, start the server:

```bash
# Development mode (with auto-reload)
npm run dev

# Or production mode
npm start
```

---

## 🔍 **How to Check if MySQL is Running**

### **Windows:**
```bash
# Using netstat
netstat -an | find "3306"

# If you see LISTENING, MySQL is running
```

### **macOS/Linux:**
```bash
# Using lsof
lsof -i :3306

# If you see a process, MySQL is running
```

---

## 📝 **Complete Setup Checklist**

- [ ] MySQL is installed on your system
- [ ] MySQL service is running (check via Services or command line)
- [ ] Database `taxi_emergency_app` exists
- [ ] `.env` file has correct database credentials
- [ ] Node dependencies are installed: `npm install`
- [ ] Database tables are created: `npm run init-db`
- [ ] Server starts successfully: `npm start` or `npm run dev`
- [ ] Server shows "🚀 Backend server running on port 3000"

---

## 🚀 **Starting Everything (Complete Workflow)**

### **Step 1: Start MySQL**
- Windows: Open Services and start MySQL service
- macOS: `brew services start mysql`
- Linux: `sudo systemctl start mysql`

### **Step 2: Navigate to Backend Directory**
```bash
cd "c:\Users\Ultra-Tech\Desktop\nelson document\dartapp\taxi_app\Backend"
```

### **Step 3: Install Dependencies (if not done)**
```bash
npm install
```

### **Step 4: Initialize Database**
```bash
npm run init-db
```

### **Step 5: Start the Server**
```bash
npm run dev
```

You should see:
```
🚀 Backend server running on port 3000
🌍 Environment: development
✅ Database connected successfully
```

---

## 🧪 **Test the Server is Running**

Open a new terminal and run:
```bash
curl http://localhost:3000/health
```

You should get:
```json
{
  "status": "OK",
  "timestamp": "2024-03-31T...",
  "uptime": 12.345
}
```

---

## 📊 **Environment File Example**

Create `.env` file in Backend directory:

```
# Database Configuration
DB_HOST=localhost
DB_USER=root
DB_PASSWORD=
DB_NAME=taxi_emergency_app
DB_PORT=3306

# Server Configuration
PORT=3000
NODE_ENV=development

# JWT Secret
JWT_SECRET=your_super_secret_jwt_key_here

# CORS Origins
CORS_ORIGINS=http://localhost:3000,http://10.0.2.2:3000
```

---

## 🆘 **Still Having Issues?**

1. **Check MySQL is actually installed**
   ```bash
   mysql --version
   ```

2. **Check if port 3306 is in use**
   ```bash
   netstat -an | find "3306"  # Windows
   lsof -i :3306              # macOS/Linux
   ```

3. **Check logs for detailed error**
   ```bash
   npm run dev  # Shows more detailed errors than npm start
   ```

4. **Try resetting MySQL**
   - Stop the MySQL service
   - Wait 10 seconds
   - Start the MySQL service again

5. **Enable debug mode**
   ```bash
   NODE_ENV=development node server.js
   ```

---

## 📞 **Common Error Messages**

| Error | Cause | Solution |
|-------|-------|----------|
| `ECONNREFUSED` | MySQL not running | Start MySQL service |
| `ER_ACCESS_DENIED_FOR_USER` | Wrong credentials | Check `.env` file |
| `ER_BAD_DB_ERROR` | Database doesn't exist | Create database: `CREATE DATABASE taxi_emergency_app;` |
| `EADDRINUSE` | Port 3000 already in use | Kill process or change PORT in `.env` |
| `Error: connect ECONNREFUSED` | Database connection refused | MySQL service is not running |

---

## ✨ **Success Indicators**

When everything is working correctly, you should see:

```
🚀 Backend server running on port 3000
🌍 Environment: development
✅ Database connected successfully
```

And when you make requests:
```
2024-03-31T12:34:56.789Z - GET /health
2024-03-31T12:34:57.123Z - POST /api/auth/login
```

---

Good luck! Your backend should now be running smoothly. 🎉