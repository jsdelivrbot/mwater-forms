var express = require('express');
var app = express();

app.use(express.static(__dirname));

app.listen(8082, function() {
	console.log("On port 8082");
});
