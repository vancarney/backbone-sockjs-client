var fs = require('fs')
,staticPath = require('serve-static')
,express = require('express')
,http = require('http')
.sockjs = require('sockjs')
,app = express()
,host = process.env.HOST || '0.0.0.0'
,port = process.env.PORT || 3000
,server = require('http').createServer(app)
,sockjs = require('sockjs').createServer({ sockjs_url: 'http://cdn.jsdelivr.net/sockjs/0.3.4/sockjs.min.js' })
,websock = require('../dist/backbone-sock-client').init( sockjs );
sockjs.installHandlers(server, {prefix:'/ws'});
server.listen(port);

app.use( staticPath('dist') );

 
app.get("/", function(req, res) {
	res.sendFile(__dirname+'/index.html');
});

 
server.listen(port, host, function() {
	return console.log("\u001b[32mService available at: \u001b[36mhttp://" + host + ":" + port + "\u001b[0m");
});
 