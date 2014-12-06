var fs = require('fs');
var staticPath = require('serve-static');
var express = require('express');
var http = require('http');
var app = express(), 
host = process.env.HOST || '0.0.0.0',
port = process.env.PORT || 3000,
server = require('http').createServer(app),
io = require('socket.io').listen(server);             // socket needs to listen on http server


io.sockets.on('connection', function(client) {
	console.log('user connected');
    client.on('message', function(data) {
    	// broadcast to clients
    	console.log(data);
        return io.sockets.emit('message', data);
     })
     .emit('HELO', new Date());
});


server.listen(port);

app.use( staticPath('dist') );

 
app.get("/", function(req, res) {
	res.sendFile(__dirname+'/index.html');
});

 
server.listen(port, host, function() {
	return console.log("\u001b[32mService available at: \u001b[36mhttp://" + host + ":" + port + "\u001b[0m");
});
 