_ = require('underscore')._
Rest = require('sphere-node-connect').Rest
OrderSync = require('sphere-node-sync').OrderSync
Q = require 'q'

class OrderStatusSync
  constructor: (@options) ->
    throw new Error 'No configuration in options!' if not @options or not @options.config
    @restTo = new Rest config: @options.config.to
    @restFrom = new Rest config: @options.config.from
    @sync = new OrderSync config: @options.config.to

#  elasticio: (msg, cfg, cb, snapshot) ->
#    if msg.attachments
#      for attachment of msg.attachments
#        continue if not attachment.match /xml$/i
#        content = msg.attachments[attachment].content
#        continue if not content
#        xmlString = new Buffer(content, 'base64').toString()
#        @run xmlString, cb
#    else if msg.body
#      # TODO: As we get only one entry here, we should query for the existing one and not
#      # get the whole inventory
#      @initMatcher().then () =>
#        @createOrUpdate([@createEntry(msg.body.SKU, msg.body.QUANTITY)], cb)
#      .fail (msg) =>
#        @returnResult false, msg, cb
#    else
#      @returnResult false, 'No data found in elastic.io msg.', cb

  getOrders: (rest) ->
    deferred = Q.defer()
    rest.GET "orders?limit=0", (error, response, body) ->
      if error
        deferred.reject "Error on fetching orders: " + error
      else if response.statusCode != 200
        deferred.reject "Problem on fetching orders (status: #{response.statusCode}): " + body
      else
        orders = JSON.parse(body).results
        deferred.resolve orders
    deferred.promise

  run: (callback) ->
    throw new Error 'Callback must be a function!' unless _.isFunction callback

    initMatcher().then (fromIndex2toIndex) =>
      process(fromIndex2toIndex).then (msg) =>
        @returnResult true, msg, callback
      .fail (msg) =>
        @returnResult false, msg, callback
    .fail (msg) =>
      @returnResult false, msg, callback

  returnResult: (positiveFeedback, msg, callback) ->
    d =
      status: positiveFeedback
      msg: msg
    callback d

  initMatcher: () ->
    deferred = Q.defer()
    Q.all([@getOrders(@restFrom), @getOrders(@restTo)]).then (ordersFrom, ordersTo) =>
      @orderFrom = orderFrom
      @ordersTo = orderTo
      fromIndex2toIndex = {}
      for oTo,i in ordersTo
        for expoInfo,j in oTo.exportedInfo
          if not expoInfo.externalId
            fromIndex2toIndex[i] = j
      deferred.resolve fromIndex2toIndex
    .fail (msg) ->
      deferred.reject msg
    deferred.promise

  process: (fromIndex2toIndex) ->
    deferred = Q.defer()
    if _.size(fromIndex2toIndex) is 0
      deferred.resolve 'Nothing to do.'
      return deferred.promise
    posts = []
    for f,t of fromIndex2toIndex
      posts.push @update(@ordersFrom[f], @ordersTo[t])
    Q.all(posts).then (msg) ->
      deferred.resolve msg
    .fail (msg) ->
      deferred.reject msg
    deferred.promise

  update: (orderFrom, orderTo) ->
    deferred = Q.defer()
    @sync.buildActions(orderFrom, orderTo).update (error, response, body) ->
      if error
        deferred.reject 'Error on updating order: ' + error
      else
        if response.statusCode is 200
          deferred.resolve 'Order updated.'
        else if response.statusCode is 304
          deferred.resolve 'Order update not necessary.'
        else
          deferred.reject 'Problem on updating existing stock (status: #{response.statusCode}): ' + body
    deferred.promise

module.exports = OrderStatusSync