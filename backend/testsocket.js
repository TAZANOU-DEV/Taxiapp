const io = require('socket.io-client');

const socket = io('http://localhost:3000');

socket.on('connect', () => {
  console.log('Connected');

  socket.emit('emergency', {
    taxiId: 'CM-TX-4589',
    message: 'Help!'
  });
});

socket.on('emergencyAlert', (data) => {
  console.log('Received alert:', data);
});
