const express = require('express');
const http = require('http');
const cors = require('cors');
const mongoose = require('mongoose');
const { Server } = require('socket.io');

const app = express();
const server = http.createServer(app);
const io = new Server(server, {
  cors: { origin: '*' }
});

app.use(cors());
app.use(express.json());

mongoose.connect(
  'mongodb+srv://username:password@cluster0.xxxxx.mongodb.net/taxi_app'
).then(() => {
  console.log('MongoDB connected');
});


app.use('/api/taxi', require('./routes/taxiroutes'));

io.on('connection', (socket) => {
  console.log('Taxi connected');

  socket.on('emergency', (data) => {
    socket.broadcast.emit('emergencyAlert', data);
  });

  socket.on('shareLocation', (data) => {
    socket.broadcast.emit('locationUpdate', data);
  });
});

server.listen(3000, () => {
  console.log('Backend running on port 3000');
});
