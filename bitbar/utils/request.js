var fs = require('fs');
var https = require('https');
var path = require('path');

function buildOptions(organization, options) {
  var defaultOptions = {
    hostname: organization.hostname || 'api.github.com',
    // port: 443,
    method: 'GET',
    headers: {
      'User-Agent': 'Github-BitBar',
      'Authorization': `token ${organization.token}`
    },
    path: (organization.path || '') + options.path
  };

  return defaultOptions;
}

module.exports = function request(organization, _options) {
  return new Promise(function(resolve, reject) {
    var responseData;
    var options = buildOptions(organization, _options);
    https.request(options, function(res) {
      res
        .on('data', (data) => {
          responseData = (responseData || '') + data;
        })
        .on('end', () => {
          resolve(JSON.parse(responseData));
        });
    })
    .on('error', reject)
    .end();
  });
}
