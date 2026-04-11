const path = require('path');
require('dotenv').config({ path: path.join(__dirname, '.env') });
const express = require('express');
const http = require('http');
const cors = require('cors');
const { Server } = require('socket.io');
const db = require('./db');
const multer = require('multer');

const app = express();
const server = http.createServer(app);

const io = new Server(server, {
  cors: {
    origin: process.env.CORS_ORIGINS ? process.env.CORS_ORIGINS.split(',') : ["*"],
    methods: ["GET", "POST", "PUT", "DELETE"],
    credentials: true
  }
});

// Configure multer for file uploads
const storage = multer.diskStorage({
  destination: (req, file, cb) => {
    cb(null, 'uploads/');
  },
  filename: (req, file, cb) => {
    const uniqueSuffix = Date.now() + '-' + Math.round(Math.random() * 1E9);
    cb(null, file.fieldname + '-' + uniqueSuffix + path.extname(file.originalname));
  }
});

const upload = multer({ storage: storage });

app.use(cors());
app.use(express.json({ limit: '10mb' }));
app.use(express.urlencoded({ extended: true }));

// Serve uploaded files
app.use('/uploads', express.static('uploads'));

// Request logging middleware
app.use((req, res, next) => {
  console.log(`${new Date().toISOString()} - ${req.method} ${req.path}`);
  next();
});

// Health check endpoint (before other routes)
app.get('/health', (req, res) => {
  res.json({
    status: 'OK',
    timestamp: new Date().toISOString(),
    uptime: process.uptime()
  });
});

// Import routes
app.use('/api/auth', require('./routes/auth'));
app.use('/api/admin', require('./routes/admin'));
app.use('/api/drivers', require('./routes/drivers'));
app.use('/api/driver-table', require('./routes/driverTable'));
app.use('/api/taxi', require('./routes/taxiroutes')(io));

// Global error handler
app.use((err, req, res, next) => {
  console.error('Error:', err);
  
  // Handle database connection errors
  if (err.code === 'PROTOCOL_CONNECTION_LOST' || err.code === 'PROTOCOL_ENQUEUE_AFTER_FATAL_ERROR' || err.code === 'PROTOCOL_ENQUEUE_AFTER_FATAL_ERROR') {
    return res.status(503).json({
      error: 'Service unavailable',
      message: 'Database connection failed. Please try again later.'
    });
  }

  res.status(500).json({
    error: 'Internal server error',
    message: process.env.NODE_ENV === 'development' ? err.message : 'Something went wrong'
  });
});

// 404 handler
app.use('*', (req, res) => {
  res.status(404).json({ error: 'Route not found' });
});

// Socket.io real-time messaging
const activeTaxis = new Map(); // Store active taxi connections

io.on('connection', (socket) => {
  console.log('🚕 Taxi connected:', socket.id);

  // Register taxi
  socket.on('register_taxi', async (data) => {
    try {
      const { taxiId, lat, lng } = data;

      // Update taxi location in database
      await db.query(`
        INSERT INTO taxis (taxi_id, lat, lng, is_online)
        VALUES (?, ?, ?, true)
        ON DUPLICATE KEY UPDATE
          lat = VALUES(lat),
          lng = VALUES(lng),
          is_online = true,
          updated_at = CURRENT_TIMESTAMP
      `, [taxiId, lat, lng]);

      // Store in memory
      activeTaxis.set(taxiId, {
        socketId: socket.id,
        lat,
        lng,
        isOnline: true,
        lastUpdate: new Date()
      });

      console.log(`✅ Taxi ${taxiId} registered at ${lat}, ${lng}`);
      io.emit('taxi_registered', { taxiId, lat, lng });
    } catch (error) {
      console.error('❌ Error registering taxi:', error);
      socket.emit('error', { message: 'Failed to register taxi' });
    }
  });

  // Broadcast taxi location updates in real-time
  socket.on('location_update', async (data) => {
    try {
      const { taxiId, lat, lng } = data;

      // Update database
      await db.query(`
        UPDATE taxis SET lat = ?, lng = ?, updated_at = CURRENT_TIMESTAMP
        WHERE taxi_id = ?
      `, [lat, lng, taxiId]);

      // Update memory
      if (activeTaxis.has(taxiId)) {
        activeTaxis.get(taxiId).lat = lat;
        activeTaxis.get(taxiId).lng = lng;
        activeTaxis.get(taxiId).lastUpdate = new Date();
      }

      // Broadcast to all connected clients
      io.emit('taxi_location_updated', {
        taxiId,
        lat,
        lng,
        timestamp: new Date()
      });

      console.log(`📍 Location update from ${taxiId}: ${lat}, ${lng}`);
    } catch (error) {
      console.error('❌ Error updating location:', error);
      socket.emit('error', { message: 'Failed to update location' });
    }
  });

  // Request taxi order
  socket.on('request_taxi', async (data) => {
    try {
      const { fromTaxiId, toTaxiId, lat, lng, reason = 'assistance' } = data;

      // Create order in database
      const [result] = await db.query(`
        INSERT INTO taxi_orders (from_taxi_id, to_taxi_id, status, pickup_lat, pickup_lng, reason)
        VALUES (?, ?, 'requested', ?, ?, ?)
      `, [fromTaxiId, toTaxiId, lat, lng, reason]);

      const orderId = result.insertId;

      console.log(`📋 Order request: ${fromTaxiId} -> ${toTaxiId} (ID: ${orderId})`);

      // Notify the target taxi
      if (activeTaxis.has(toTaxiId)) {
        const targetSocket = io.sockets.sockets.get(activeTaxis.get(toTaxiId).socketId);
        if (targetSocket) {
          targetSocket.emit('incoming_order', {
            orderId,
            fromTaxiId,
            lat,
            lng,
            reason,
            timestamp: new Date()
          });
        }
      }

      // Broadcast to everyone for tracking
      io.emit('new_order', {
        orderId,
        fromTaxiId,
        toTaxiId,
        lat,
        lng,
        reason,
        status: 'requested',
        timestamp: new Date()
      });
    } catch (error) {
      console.error('❌ Error creating order:', error);
      socket.emit('error', { message: 'Failed to create order' });
    }
  });

  // Accept order
  socket.on('accept_order', async (data) => {
    try {
      const { orderId, taxiId, fromTaxiId } = data;

      // Update order status in database
      await db.query(`
        UPDATE taxi_orders SET status = 'accepted', updated_at = CURRENT_TIMESTAMP
        WHERE id = ? AND to_taxi_id = ?
      `, [orderId, taxiId]);

      io.emit('order_accepted', {
        orderId,
        taxiId,
        fromTaxiId,
        timestamp: new Date()
      });

      console.log(`✅ Order ${orderId} accepted by ${taxiId}`);
    } catch (error) {
      console.error('❌ Error accepting order:', error);
      socket.emit('error', { message: 'Failed to accept order' });
    }
  });

  // Update taxi status (on way, arrived, etc)
  socket.on('order_status', async (data) => {
    try {
      const { orderId, status, taxiId, lat, lng } = data;

      // Update order status in database
      await db.query(`
        UPDATE taxi_orders SET status = ?, updated_at = CURRENT_TIMESTAMP
        WHERE id = ?
      `, [status, orderId]);

      // Log activity
      await db.query(`
        INSERT INTO activities (taxi_id, title, type) VALUES (?, ?, 'order')
      `, [taxiId, `Order ${orderId} status: ${status}`]);

      io.emit('order_status_updated', {
        orderId,
        status,
        taxiId,
        lat,
        lng,
        timestamp: new Date()
      });

      console.log(`📊 Order ${orderId} status updated to ${status} by ${taxiId}`);
    } catch (error) {
      console.error('❌ Error updating order status:', error);
      socket.emit('error', { message: 'Failed to update order status' });
    }
  });

  // Emergency alert
  socket.on('emergency', async (data) => {
    try {
      const { taxiId, lat, lng, message = 'Emergency alert' } = data;

      // Log emergency in database
      await db.query(`
        INSERT INTO activities (taxi_id, title, description, type)
        VALUES (?, ?, ?, 'emergency')
      `, [taxiId, '🚨 Emergency Alert', message]);

      io.emit('emergencyAlert', {
        taxiId,
        lat,
        lng,
        message,
        timestamp: new Date()
      });

      console.log('🚨 Emergency broadcast from:', taxiId);
    } catch (error) {
      console.error('❌ Error processing emergency:', error);
      socket.emit('error', { message: 'Failed to send emergency alert' });
    }
  });

  // Share location
  socket.on('shareLocation', async (data) => {
    try {
      const { taxiId, lat, lng } = data;

      // Update location in database
      await db.query(`
        UPDATE taxis SET lat = ?, lng = ?, updated_at = CURRENT_TIMESTAMP
        WHERE taxi_id = ?
      `, [lat, lng, taxiId]);

      // Log activity
      await db.query(`
        INSERT INTO activities (taxi_id, title, type) VALUES (?, ?, 'location')
      `, [taxiId, '📍 Location shared']);

      io.emit('locationUpdate', {
        taxiId,
        lat,
        lng,
        timestamp: new Date()
      });

      console.log('📍 Location shared by:', taxiId);
    } catch (error) {
      console.error('❌ Error sharing location:', error);
      socket.emit('error', { message: 'Failed to share location' });
    }
  });

  // Disconnect
  socket.on('disconnect', () => {
    console.log('🚕 Taxi disconnected:', socket.id);

    // Remove from active taxis and update database
    for (const [taxiId, info] of activeTaxis.entries()) {
      if (info.socketId === socket.id) {
        activeTaxis.delete(taxiId);

        // Update database to mark offline
        db.query(`
          UPDATE taxis SET is_online = false, updated_at = CURRENT_TIMESTAMP
          WHERE taxi_id = ?
        `, [taxiId]).catch(err => console.error('Error updating offline status:', err));

        io.emit('taxi_offline', { taxiId });
        console.log(`📴 Taxi ${taxiId} marked offline`);
        break;
      }
    }
  });
});

const PORT = process.env.PORT || 3000;
server.listen(PORT, () => {
  console.log(`🚀 Backend server running on port ${PORT}`);
  console.log(`🌍 Environment: ${process.env.NODE_ENV || 'development'}`);
});
