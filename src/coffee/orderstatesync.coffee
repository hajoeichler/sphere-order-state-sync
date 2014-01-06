_ = require('underscore')._
Rest = require('sphere-node-connect').Rest
OrderSync = require('sphere-node-sync').OrderSync
CommonUpdater = require('sphere-node-sync').CommonUpdater
Q = require 'q'

class OrderStateSync extends CommonUpdater
  constructor: (options = {}) ->
    throw new Error 'No configuration in options!' unless options.config
    @sync = new OrderSync config: options.config

  elasticio: (msg, cfg, cb, snapshot) ->
    if msg.body
      ordersFrom = msg.body.results
      @run(ordersFrom, cb)
    else
      @returnResult false, 'No data found in elastic.io msg!', cb

  getOrders: (rest) ->
    deferred = Q.defer()
    rest.GET "/orders?limit=0", (error, response, body) ->
      if error
        deferred.reject "Error on fetching orders: " + error
      else if response.statusCode isnt 200
        deferred.reject "Problem on fetching orders (status: #{response.statusCode}): " + body
      else
        orders = JSON.parse(body).results
        deferred.resolve orders
    deferred.promise

  run: (ordersFrom, callback) ->
    throw new Error 'Callback must be a function!' unless _.isFunction callback
    @initMatcher(ordersFrom).then (fromIndex2toIndex) =>
#      @initProgressBar 'Updating order states', _.size(fromIndex2toIndex)
      @process(fromIndex2toIndex).then (msg) =>
        @returnResult true, msg, callback
      .fail (msg) =>
        @returnResult false, msg, callback
    .fail (msg) =>
      @returnResult false, msg, callback

  initMatcher: (ordersFrom) ->
    @ordersFrom = ordersFrom
    deferred = Q.defer()
    @getOrders(@sync._rest).then (ordersTo) =>
      @ordersTo = ordersTo
      fromIndex2toIndex = {}
      for oTo,i in @ordersTo
        continue unless oTo.syncInfo
        for expoInfo in oTo.syncInfo
          if expoInfo.externalId
            for oFrom,j in @ordersFrom
              if oFrom.id is expoInfo.externalId
                fromIndex2toIndex[j] = i
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
    @sync.buildActions(orderFrom, orderTo).update (error, response, body) =>
      @tickProgress()
      if error
        deferred.reject 'Error on updating order: ' + error
      else
        if response.statusCode is 200
          deferred.resolve 'Order state updated.'
        else if response.statusCode is 304
          deferred.resolve 'Order state update not necessary.'
        else
          deferred.reject 'Problem on updating order state (status: #{response.statusCode}): ' + body
    deferred.promise

module.exports = OrderStateSync