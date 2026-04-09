# 🚀 How to Run Your Taxi App

## 📁 Project Structure

Your project has two separate components that run independently:

```
taxi_app/
├── Backend/                    ← Node.js + Express Server
│   ├── server.js              ← Backend runs on port 3000
│   ├── db.js
│   ├── routes/
│   └── package.json
│
└── lib/                        ← Flutter Frontend App
    ├── main.dart
    ├── home_page.dart
    └── service/
```

**Key Point**: Backend and Frontend run on **separate processes** and communicate via HTTP/Socket.IO.

---

## ✅ Prerequisites (One-Time Setup)

### 1. **Install MySQL** (if not already installed)

**Windows:**
- Download: https://dev.mysql.com/downloads/mysql/
- Or use WAMP: http://www.wampserver.com/
- Or use XAMPP: https://www.apachefriends.org/

**macOS:**
```bash
brew install mysql
```

**Linux:**
```bash
sudo apt-get install mysql-server
```

### 2. **Install Node.js Dependencies**

Run once in the Backend directory:
```bash
cd Backend
npm install
```

### 3. **Initialize Database**

```bash
cd Backend
npm run init-db
```

This creates:
- ✅ Database `taxi_emergency_app`
- ✅ Tables (users, taxis, taxi_orders, activities)
- ✅ Sample data and users

---

## 🚀 Running the App (Daily)

### **Step 1: Start MySQL Server** (Critical!)

Choose your method:

**Windows (WAMP):**
1. Open WAMP Control Panel
2. Click "Start All"
3. Wait for MySQL to show as running (green)

**Windows (XAMPP):**
1. Open XAMPP Control Panel
2. Click "Start" next to MySQL
3. Wait for it to show as running

**Windows (MySQL Service):**
1. Press `Windows + R`
2. Type `services.msc` and Enter
3. Find "MySQL80" or "MySQL"
4. Right-click → "Start"

**macOS:**
```bash
brew services start mysql
```

**Linux:**
```bash
sudo systemctl start mysql
```

### **Step 2: Start Backend Server (Terminal 1)**

From project root:
```bash
npm run server
```

You should see:
```
🚀 Backend server running on port 3000
🌍 Environment: development
✅ Database connected successfully
```

### **Step 3: Start Flutter Frontend (Terminal 2)**

From project root:
```bash
npm run client
```

Or directly:
```bash
flutter run
```

Select your platform:
- Press `a` for Android
- Press `i` for iOS (macOS only)
- Press `w` for Windows

---

## 📝 Available Commands

### **Backend Commands** (run from project root)

```bash
npm run server              # Start backend (development with auto-reload)
npm run server:prod        # Start backend (production)
npm run server:init-db     # Initialize/reset database
npm run server:test-mysql  # Test MySQL connection
```

### **Frontend Commands** (run from project root)

```bash
npm run client            # Run Flutter app
npm run build:apk         # Build Android APK
npm run build:ios         # Build iOS app
```

### **Direct Backend Commands** (if in Backend directory)

```bash
npm run dev               # Development mode
npm start                 # Production mode
npm run init-db          # Initialize database
npm run test-mysql       # Test MySQL connection
```

---

## 🧪 Verify Everything is Working

### **Test 1: Check MySQL Connection**

```bash
npm run server:test-mysql
```

Output should show:
- ✅ Connected to MySQL server
- ✅ Database "taxi_emergency_app" exists
- ✅ Found X table(s)

### **Test 2: Check Backend is Running**

Open new terminal and run:
```bash
curl http://localhost:3000/health
```

Response should be:
```json
{
  "status": "OK",
  "timestamp": "2024-03-31T...",
  "uptime": 12.345
}
```

### **Test 3: Check Frontend Connection**

The Flutter app should:
1. Start without errors
2. Show login screen
3. Connect to backend successfully

Try logging in:
- Email: `admin@taxiapp.com`
- Password: `admin123`

---

## 📊 Example Complete Workflow

### **Terminal 1: Backend**
```bash
$ npm run server

> taxi_app@1.0.0 server
> cd Backend && npm run dev

> taxi-app-backend@1.0.0 dev
> nodemon server.js

🚀 Backend server running on port 3000
🌍 Environment: development
✅ Database connected successfully
```

### **Terminal 2: Frontend**
```bash
$ npm run client

Launching lib/main.dart on SM G570F in debug mode...
✓ Built build/app/outputs/flutter-apk/app-debug.apk in 15s
Installing and launching...
D/Flutter  (16826): DartVM start time in milliseconds: 968
I/FlutterActivityAndroidLifecycle(16826): onCreate...
✓ Flutter app installed and started
```

Both running = **Success!** 🎉

---

## ⚠️ Common Issues & Solutions

### **❌ Error: "Cannot find module 'server.js'"**

**Cause**: Running `npm start` from wrong directory

**Solution**: Use `npm run server` from project root, not `npm start`

---

### **❌ Error: "MySQL Connection Test Failed"**

**Cause**: MySQL is not running

**Solution**:
1. Start MySQL (see Step 1 above)
2. Run `npm run server:test-mysql` to verify
3. Then start backend with `npm run server`

---

### **❌ Error: "Port 3000 already in use"**

**Cause**: Backend is already running or another app uses port 3000

**Solution**:
```bash
# Kill the process using port 3000
# Windows:
netstat -ano | findstr :3000
taskkill /PID <PID> /F

# macOS/Linux:
lsof -i :3000
kill -9 <PID>
```

Or change port in `Backend/.env`:
```env
PORT=3001
```

---

### **❌ Error: "Flutter can't connect to backend"**

**Cause**: Backend not running or wrong address

**Solution**:
1. Ensure backend runs: `npm run server`
2. Test: `npm run server:test-mysql`
3. For Android emulator, check `lib/service/socket_service.dart` uses `10.0.2.2` not `localhost`
4. For physical device, use your computer's IP (e.g., `192.168.1.x`)

---

### **❌ Error: "Database 'taxi_emergency_app' not found"**

**Cause**: Database not initialized

**Solution**:
```bash
npm run server:init-db
```

---

## 🎯 Quick Start Checklist

- [ ] MySQL is installed and can be started
- [ ] Node.js is installed (`node --version` shows v16+)
- [ ] Backend dependencies installed (`cd Backend && npm install`)
- [ ] Database initialized (`npm run server:init-db`)
- [ ] **MySQL service is running** (critical!)
- [ ] Backend starts: `npm run server` → shows ✅ Database connected
- [ ] Frontend starts: `npm run client` → shows login screen
- [ ] Can login: admin@taxiapp.com / admin123

---

## 📚 Detailed Guides

For more information, see:
- **[Backend/MYSQL_SETUP.md](./Backend/MYSQL_SETUP.md)** - MySQL setup and configuration
- **[Backend/README.md](./Backend/README.md)** - API documentation
- **[Backend/TROUBLESHOOTING.md](./Backend/TROUBLESHOOTING.md)** - Detailed troubleshooting
- **[Backend/FIX_SUMMARY.md](./Backend/FIX_SUMMARY.md)** - What was fixed and why

---

## ✨ Key Takeaways

### **Remember:**
1. **MySQL must be running first** - Without it, backend can't start
2. **Two separate processes** - Backend and Frontend run independently
3. **Use `npm run server`** - Not `npm start` or `npm run dev`
4. **Check ports** - Backend uses 3000, Flutter uses various ports
5. **Test MySQL first** - Run `npm run server:test-mysql` before starting backend

### **Happy developing!** 🚀

If issues persist, check the detailed guides above or enable debug mode and review logs.
