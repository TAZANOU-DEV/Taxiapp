# Complete Setup Guide - Taxi Emergency App

## 🎯 Overview

This guide will walk you through setting up and running the complete Taxi Emergency App system, including the Flutter frontend and Node.js backend.

---

## 📋 System Requirements

- **Node.js**: v16 or higher
- **Flutter**: Latest version
- **MySQL**: v5.7 or higher
- **Text Editor/IDE**: VS Code, Android Studio, or similar
- **Memory**: At least 4GB RAM
- **Disk Space**: At least 5GB free

---

## 🚀 Quick Start (5 minutes)

### 1. **Start MySQL Server**

#### Windows (WAMP/XAMPP):
- Open WAMP Control Panel or XAMPP Control Panel
- Click "Start All"
- Wait for MySQL to show as running (green)

#### Windows (MySQL Service):
- Open `services.msc`
- Find "MySQL80" or "MySQL"
- Right-click and select "Start"

#### macOS:
```bash
brew services start mysql
```

#### Linux:
```bash
sudo systemctl start mysql
```

### 2. **Start Backend Server**

```bash
cd "Backend"
npm install
npm run init-db
npm run dev
```

You should see:
```
🚀 Backend server running on port 3000
🌍 Environment: development
✅ Database connected successfully
```

### 3. **Start Flutter App**

In a new terminal:
```bash
cd ..
flutter pub get
flutter run
```

**Done!** Your app is now running and connected to the backend.

---

## 📁 Detailed Setup Instructions

### **Part 1: Backend Setup**

#### Step 1.1: Navigate to Backend Directory
```bash
cd "c:\Users\Ultra-Tech\Desktop\nelson document\dartapp\taxi_app\Backend"
```

#### Step 1.2: Install Dependencies
```bash
npm install
```

Wait for completion. You should see:
```
added 144 packages in 14s
```

#### Step 1.3: Configure Environment Variables

Check that `.env` file exists and has the correct content:

```env
DB_HOST=localhost
DB_USER=root
DB_PASSWORD=
DB_NAME=taxi_emergency_app
DB_PORT=3306
PORT=3000
NODE_ENV=development
JWT_SECRET=your_super_secret_jwt_key_here
CORS_ORIGINS=http://localhost:3000,http://10.0.2.2:3000
```

#### Step 1.4: Verify MySQL is Running

```bash
# Test connection
mysql -h localhost -u root

# You should get the MySQL prompt
mysql>
```

If you get a connection error, MySQL is not running. Go back and start MySQL.

#### Step 1.5: Initialize Database

```bash
npm run init-db
```

You should see:
```
🚀 Initializing database...
✅ Database created or already exists
✅ Taxis table created
✅ Activities table created
✅ Taxi orders table created
✅ Users table created
✅ Sample data inserted
✅ Sample users created
🎉 Database initialization completed successfully!
```

#### Step 1.6: Start Backend Server

```bash
npm run dev
```

You should see:
```
🚀 Backend server running on port 3000
🌍 Environment: development
✅ Database connected successfully
```

**Backend is now running!** ✅

---

### **Part 2: Frontend (Flutter) Setup**

#### Step 2.1: Navigate to App Directory

Open a new terminal:
```bash
cd "c:\Users\Ultra-Tech\Desktop\nelson document\dartapp\taxi_app"
```

#### Step 2.2: Get Dependencies

```bash
flutter pub get
```

Wait for completion.

#### Step 2.3: Run the App

```bash
flutter run
```

Choose your platform:
- **Android**: Press `a`
- **iOS**: Press `i` (macOS only)
- **Windows**: Press `w`

The app should start and automatically connect to your backend at `localhost:3000` (or `10.0.2.2:3000` for Android emulator).

---

## 🧪 Testing the Setup

### Test Backend is Running

Open a new terminal:
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

### Test Database Connection

```bash
mysql -h localhost -u root taxi_emergency_app
```

Then:
```sql
SHOW TABLES;
SELECT * FROM users;
EXIT;
```

You should see the created tables and sample users.

### Test Flutter App

1. The app should start without errors
2. You should see the login screen
3. Try logging in with:
   - **Email**: admin@taxiapp.com
   - **Password**: admin123

---

## 📚 API Endpoints (for testing)

All endpoints are available at: `http://localhost:3000`

### Authentication
- `POST /api/auth/register` - Register new user
- `POST /api/auth/login` - User login
- `GET /api/auth/profile` - Get profile
- `PUT /api/auth/profile` - Update profile
- `PUT /api/auth/password` - Change password

### Taxi Operations
- `POST /api/taxi/location` - Share location
- `POST /api/taxi/emergency` - Emergency alert
- `GET /api/taxi/nearby` - Get nearby taxis
- `GET /api/taxi/activities/:taxiId` - Activity history
- `POST /api/taxi/order` - Create order
- `GET /api/taxi/orders/:taxiId` - Get orders
- `PUT /api/taxi/order/:orderId` - Update order
- `GET /api/taxi/stats` - Dashboard stats

### Health Check
- `GET /health` - Server health status

---

## 🐛 Troubleshooting

### Issue: "Database connection failed"

**Solution**: Ensure MySQL is running
```bash
# Windows
netstat -an | find "3306"

# macOS/Linux
lsof -i :3306
```

If not running, start the MySQL service.

### Issue: "Port 3000 already in use"

**Solution**: Change the port in `.env`:
```env
PORT=3001
```

Then start the server again.

### Issue: "npm: command not found"

**Solution**: Node.js is not installed. Download and install from [nodejs.org](https://nodejs.org)

### Issue: Flutter can't connect to backend

**Solution**: 
- For Android emulator: Make sure backend is running on `10.0.2.2:3000`
- For physical device: Change `socket_service.dart` to use your machine's IP instead of localhost
- For iOS simulator: Use `localhost:3000`

See [TROUBLESHOOTING.md](./TROUBLESHOOTING.md) for more detailed solutions.

---

## 📊 Project Structure

```
taxi_app/
├── Backend/
│   ├── routes/
│   │   ├── auth.js
│   │   ├── admin.js
│   │   └── taxiroutes.js
│   ├── scripts/
│   │   └── init-db.js
│   ├── server.js
│   ├── db.js
│   ├── package.json
│   ├── .env
│   ├── README.md
│   └── TROUBLESHOOTING.md
├── lib/
│   ├── main.dart
│   ├── home_page.dart
│   ├── login_page.dart
│   ├── settings_page.dart
│   ├── service/
│   │   └── socket_service.dart
│   └── ...
├── android/
├── ios/
├── web/
└── pubspec.yaml
```

---

## 🔐 Default Credentials

After running `npm run init-db`, you can login with:

**Admin Account:**
- Email: `admin@taxiapp.com`
- Password: `admin123`

**Driver Accounts:**
- Email: `driver1@taxiapp.com`
- Password: `driver123`

Or

- Email: `driver2@taxiapp.com`
- Password: `driver123`

---

## 🚀 Development Workflow

### Terminal 1: Backend
```bash
cd Backend
npm run dev
```

### Terminal 2: Frontend
```bash
flutter run
```

### Terminal 3: MySQL (if needed)
```bash
mysql -h localhost -u root taxi_emergency_app
```

---

## 📱 Building for Production

### Build Flutter APK (Android)
```bash
flutter build apk
```

### Build Flutter IPA (iOS)
```bash
flutter build ios
```

### Deploy Backend

See [Backend/README.md](./Backend/README.md) for production deployment instructions.

---

## 🤝 Contributing

1. Create a new branch: `git checkout -b feature/your-feature`
2. Make your changes
3. Test thoroughly
4. Commit: `git commit -m "Add your feature"`
5. Push: `git push origin feature/your-feature`
6. Create a Pull Request

---

## 📞 Support

If you encounter any issues:

1. Check [TROUBLESHOOTING.md](./Backend/TROUBLESHOOTING.md)
2. Verify all prerequisites are installed
3. Ensure MySQL is running
4. Check that all credentials in `.env` are correct
5. Review the console output for specific error messages

---

## ✨ Next Steps

After setup:
1. ✅ Customize the app with your branding
2. ✅ Add your logo and app icon
3. ✅ Test all features with real data
4. ✅ Set up production database
5. ✅ Deploy backend to a server
6. ✅ Publish app to app stores

---

**Happy coding!** 🎉

For more detailed information, see:
- [Backend README](./Backend/README.md)
- [Database Recommendations](./Backend/DATABASE_RECOMMENDATIONS.md)
- [Troubleshooting Guide](./Backend/TROUBLESHOOTING.md)