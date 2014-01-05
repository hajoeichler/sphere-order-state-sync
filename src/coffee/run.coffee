Config = require '../config'
argv = require('optimist')
  .usage('Usage: $0 --projectKey key --clientId id --clientSecret secret')
  .demand(['projectKey','clientId', 'clientSecret'])
  .argv
OrderStateSync = require('../main').OrderStateSync
Rest = require('sphere-node-connect').Rest

options =
  config:
    project_key: argv.projectKey
    client_id: argv.clientId
    client_secret: argv.clientSecret

sync = new OrderStateSync Config
rest = new Rest options
sync.getOrders(rest).then (orders) ->
  sync.run orders, (msg) ->
    console.log msg
    process.exit 1 unless msg.status
    process.exit 0 # TODO - this shouldn't be necessary - but currently the program hangs at the end
.fail (msg) ->
  console.log msg
  process.exit 2