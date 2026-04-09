# Quick Reference - Taxi App Commands

## 🚀 Start Everything (One-Time Setup)

```bash
# 1. Start MySQL (choose your method below)

# Windows - WAMP Control Panel:
# Open WAMP Control Panel → Click "Start All"

# Windows - MySQL Service:
# Open services.msc → Find MySQL → Right-click → Start

# macOS:
brew services start mysql

# Linux:
sudo systemctl start mysql


# 2. Navigate to project
cd "c:\Users\Ultra-Tech\Desktop\nelson document\dartapp\taxi_app"


# 3. Setup Backend (first time only)
cd Backend
npm install
npm run init-db


# 4. Start Backend (in Terminal 1)
npm run dev
# You should see: 🚀 Backend server running on port 3000


# 5. Start Frontend (in Terminal 2)
cd ..
flutter pub get
flutter run
```

---

## ⚡ Daily Startup (After First Setup)

### **Terminal 1 - Backend:**
```bash
cd "c:\Users\Ultra-Tech\Desktop\nelson document\dartapp\taxi_app\Backend"
npm run dev
```

### **Terminal 2 - Frontend:**
```bash
cd "c:\Users\Ultra-Tech\Desktop\nelson document\dartapp\taxi_app"
flutter run
```

---

## 🧪 Testing

### Test Backend
```bash
curl http://localhost:3000/health
```

Expected response:
```json
{
  "status": "OK",
  "timestamp": "2024-03-31T...",
  "uptime": 12.345
}
```

### Test Database
```bash
mysql -h localhost -u root taxi_emergency_app
SHOW TABLES;
EXIT;
```

---

## 🔑 Default Login Credentials

| Role | Email | Password |
|------|-------|----------|
| **Admin** | admin@taxiapp.com | admin123 |
| **Driver 1** | driver1@taxiapp.com | driver123 |
| **Driver 2** | driver2@taxiapp.com | driver123 |

---

## 📚 Useful Commands

```bash
# Backend Development
npm run dev          # Start with auto-reload
npm start            # Start production server
npm run init-db      # Initialize/reset database

# Flutter Development
flutter run          # Run app
flutter pub get      # Get dependencies
flutter clean        # Clean build cache
flutter build apk    # Build Android APK

# MySQL
mysql -h localhost -u root                    # Connect to MySQL
mysql -h localhost -u root taxi_emergency_app # Connect to app database

# Check if ports are in use
netstat -an | find "3000"   # Windows
netstat -an | find "3306"   # Windows
lsof -i :3000              # macOS/Linux
lsof -i :3306              # macOS/Linux
```

---

## 🆘 Quick Fixes

### Server crashes with "Database connection failed"
**Fix**: Start MySQL service
- Windows: Open WAMP/XAMPP and click Start
- macOS: `brew services start mysql`
- Linux: `sudo systemctl start mysql`

### Port 3000 already in use
**Fix**: Change port in `Backend/.env`:
```env
PORT=3001
```

### Flutter can't connect to backend
**Android Emulator**: Use `10.0.2.2:3000` instead of `localhost:3000`
**Physical Device**: Use your computer's IP address (e.g., `192.168.x.x:3000`)

### Need to reset database
```bash
cd Backend
npm run init-db
```

---

## 📍 Important Paths

```
Project Root:
c:\Users\Ultra-Tech\Desktop\nelson document\dartapp\taxi_app\

Backend:
c:\Users\Ultra-Tech\Desktop\nelson document\dartapp\taxi_app\Backend\

Frontend Code:
c:\Users\Ultra-Tech\Desktop\nelson document\dartapp\taxi_app\lib\

Database Config:
c:\Users\Ultra-Tech\Desktop\nelson document\dartapp\taxi_app\Backend\.env
```

---

## 📖 Read These Files

1. **[SETUP.md](./SETUP.md)** - Complete setup instructions
2. **[Backend/README.md](./Backend/README.md)** - Backend API documentation
3. **[Backend/TROUBLESHOOTING.md](./Backend/TROUBLESHOOTING.md)** - Detailed troubleshooting
4. **[Backend/DATABASE_RECOMMENDATIONS.md](./Backend/DATABASE_RECOMMENDATIONS.md)** - Database options

---

## 🎯 Checklist

### Before Running
- [ ] MySQL is installed
- [ ] Node.js is installed (v16+)
- [ ] Flutter is installed and updated
- [ ] `.env` file exists in Backend folder
- [ ] All local paths are correct

### First Time Setup
- [ ] Run `npm install` in Backend
- [ ] Run `npm run init-db` in Backend
- [ ] Start MySQL service
- [ ] Start backend server
- [ ] Start frontend with `flutter run`

### Daily Startup
- [ ] Start MySQL service
- [ ] Start backend: `npm run dev`
- [ ] Start frontend: `flutter run`
- [ ] Test endpoints at `http://localhost:3000/health`

---

## ✨ You're All Set!

Your app is now running with:
- ✅ Flutter frontend
- ✅ Node.js backend
- ✅ MySQL database
- ✅ Real-time Socket.IO communication
- ✅ Authentication system
- ✅ Taxi management system
- ✅ Emergency alert system

**Happy developing!** 🚀