OrderStatusSync = require('./main').OrderStatusSync

exports.process = function(msg, cfg, cb, snapshot) {
  config = {
    client_id: cfg.clientId,
    client_secret: cfg.clientSecret,
    project_key: cfg.projectKey
  };
  var oss = new OrderStatusSync({
    config: config
  });
  oss.elasticio(msg, cfg, cb, snapshot);
}