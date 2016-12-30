var fs = require('fs');
var path = require('path');

module.exports = JSON.parse(fs.readFileSync(path.resolve(__dirname, '..', 'plugins', '.github.json'), 'utf-8'));
