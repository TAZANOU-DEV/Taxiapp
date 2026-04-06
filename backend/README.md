# Taxi Emergency App - Backend

A comprehensive backend API for a taxi emergency and communication application built with Node.js, Express, Socket.IO, and MySQL.

## Features

- 🚕 **Real-time Communication**: Socket.IO for live taxi coordination
- 🔐 **Authentication**: JWT-based user authentication
- 📍 **Location Tracking**: Real-time GPS location sharing
- 🚨 **Emergency System**: Instant emergency alerts
- 📋 **Order Management**: Taxi request and dispatch system
- 👥 **Admin Dashboard**: Administrative controls and analytics
- 📊 **Activity Logging**: Comprehensive logging system

## Tech Stack

- **Runtime**: Node.js
- **Framework**: Express.js
- **Real-time**: Socket.IO
- **Database**: MySQL
- **Authentication**: JWT (JSON Web Tokens)
- **Password Hashing**: bcryptjs

## Prerequisites

- Node.js (v16 or higher)
- MySQL Server
- npm or yarn

## Installation

1. **Clone the repository**
   ```bash
   git clone https://github.com/TAZANOU-DEV/Taxiapp.git
   cd Taxiapp/Backend
   ```

2. **Install dependencies**
   ```bash
   npm install
   ```

3. **Environment Setup**
   - Copy `.env` file and update the values:
   ```bash
   cp .env.example .env
   ```
   - Update the following variables in `.env`:
   ```
   DB_HOST=localhost
   DB_USER=your_mysql_username
   DB_PASSWORD=your_mysql_password
   DB_NAME=taxi_emergency_app
   JWT_SECRET=your_super_secret_jwt_key_here
   PORT=3000
   ```

4. **Database Setup**
   - Create MySQL database: `taxi_emergency_app`
   - Run the database initialization script:
   ```bash
   npm run init-db
   ```

## Running the Application

### Development Mode
```bash
npm run dev
```

### Production Mode
```bash
npm start
```

The server will start on port 3000 (or the port specified in `.env`).

## API Endpoints

### Authentication
- `POST /api/auth/register` - Register new user
- `POST /api/auth/login` - User login
- `GET /api/auth/profile` - Get user profile
- `PUT /api/auth/profile` - Update user profile
- `PUT /api/auth/password` - Change password

### Taxi Operations
- `POST /api/taxi/location` - Share location
- `POST /api/taxi/emergency` - Send emergency alert
- `GET /api/taxi/nearby` - Get nearby taxis
- `GET /api/taxi/activities/:taxiId` - Get activity history
- `POST /api/taxi/order` - Create taxi order
- `GET /api/taxi/orders/:taxiId` - Get orders for taxi
- `PUT /api/taxi/order/:orderId` - Update order status
- `GET /api/taxi/profile/:taxiId` - Get taxi profile
- `GET /api/taxi/stats` - Get dashboard statistics

### Admin Operations
- `GET /api/admin/taxis` - Get all taxis
- `GET /api/admin/orders` - Get all orders
- `GET /api/admin/stats` - Get system statistics
- `GET /api/admin/emergencies` - Get emergency alerts
- `PUT /api/admin/taxi/:taxiId/status` - Update taxi status
- `GET /api/admin/activities` - Get activity logs

## Socket.IO Events

### Client to Server
- `register_taxi` - Register taxi with location
- `location_update` - Update taxi location
- `request_taxi` - Request taxi assistance
- `accept_order` - Accept taxi order
- `order_status` - Update order status
- `emergency` - Send emergency alert
- `shareLocation` - Share location
- `disconnect` - Handle disconnection

### Server to Client
- `taxi_registered` - Taxi registration confirmation
- `taxi_location_updated` - Location update broadcast
- `new_order` - New order notification
- `incoming_order` - Incoming order for taxi
- `order_accepted` - Order acceptance notification
- `order_status_updated` - Order status update
- `emergencyAlert` - Emergency alert broadcast
- `locationUpdate` - Location share notification
- `taxi_offline` - Taxi offline notification

## Database Schema

### Tables
- `users` - User accounts and authentication
- `taxis` - Taxi/driver information and status
- `taxi_orders` - Taxi service requests and orders
- `activities` - Activity logging and history

## Sample Data

The initialization script creates sample users:
- **Admin**: admin@taxiapp.com / admin123
- **Drivers**: driver1@taxiapp.com / driver123, driver2@taxiapp.com / driver123

## Security Features

- JWT token authentication
- Password hashing with bcrypt
- CORS protection
- Input validation
- SQL injection prevention
- Rate limiting (recommended for production)

## Development

### Project Structure
```
Backend/
├── routes/
│   ├── auth.js          # Authentication routes
│   ├── admin.js         # Admin routes
│   └── taxiroutes.js    # Taxi operation routes
├── scripts/
│   └── init-db.js       # Database initialization
├── server.js            # Main server file
├── db.js               # Database connection
├── .env                # Environment variables
└── package.json        # Dependencies
```

### Adding New Features
1. Create new route files in `routes/` directory
2. Import and use them in `server.js`
3. Update database schema if needed
4. Add appropriate middleware for authentication/security

## Deployment

### Environment Variables for Production
```env
NODE_ENV=production
DB_HOST=your_production_db_host
DB_USER=your_production_db_user
DB_PASSWORD=your_production_db_password
DB_NAME=your_production_db_name
JWT_SECRET=your_secure_jwt_secret
PORT=3000
CORS_ORIGINS=https://yourdomain.com
```

### PM2 Process Manager (Recommended)
```bash
npm install -g pm2
pm2 start server.js --name "taxi-backend"
pm2 startup
pm2 save
```

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test thoroughly
5. Submit a pull request

## License

ISC License - see LICENSE file for details.

## Support

For support, email support@taxiapp.com or create an issue in the repository.