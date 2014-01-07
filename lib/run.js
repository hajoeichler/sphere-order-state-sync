/* ===========================================================
# sphere-order-state-sync - v0.0.10
# ==============================================================
# Copyright (c) 2013 Hajo Eichler
# Licensed under the MIT license.
*/
var Config, OrderStateSync, Rest, argv, options, rest, sync;

Config = require('../config');

argv = require('optimist').usage('Usage: $0 --projectKey key --clientId id --clientSecret secret').demand(['projectKey', 'clientId', 'clientSecret']).argv;

OrderStateSync = require('../main').OrderStateSync;

Rest = require('sphere-node-connect').Rest;

options = {
  config: {
    project_key: argv.projectKey,
    client_id: argv.clientId,
    client_secret: argv.clientSecret
  }
};

sync = new OrderStateSync(Config);

rest = new Rest(options);

sync.getOrders(rest).then(function(orders) {
  return sync.run(orders, function(msg) {
    console.log(msg);
    if (!msg.status) {
      process.exit(1);
    }
    return process.exit(0);
  });
}).fail(function(msg) {
  console.log(msg);
  return process.exit(2);
});
