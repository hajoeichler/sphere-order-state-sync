Config = require '../config'
argv = require('optimist')
  .usage('Usage: $0 --projectKey key --clientId id --clientSecret secret')
  .demand(['projectKey','clientId', 'clientSecret'])
  .argv
OrderStatusSync = require('../main').OrderStatusSync
Rest = require('sphere-node-connect').Rest

Config.timeout = 120000

c =
  project_key: argv.projectKey
  client_id: argv.clientId
  client_secret: argv.clientSecret

updater = new OrderStatusSync Config
rest = new Rest config: c
updater.getOrders(rest).then (orders) ->
  updater.run orders, (msg) ->
    console.log msg
.fail (msg) ->
  console.log msg