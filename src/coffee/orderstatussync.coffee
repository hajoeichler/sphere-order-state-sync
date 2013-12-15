_ = require('underscore')._
Rest = require('sphere-node-connect').Rest
OrderSync = require('sphere-node-sync').OrderSync
ProgressBar = require 'progress'
Q = require 'q'

class OrderStatusSync
  constructor: (@options) ->
    throw new Error 'No configuration in options!' if not @options or not @options.config
    @sync = new OrderSync config: @options.config

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
      else if response.statusCode != 200
        deferred.reject "Problem on fetching orders (status: #{response.statusCode}): " + body
      else
        orders = JSON.parse(body).results
        deferred.resolve orders
    deferred.promise

  run: (ordersFrom, callback) ->
    throw new Error 'Callback must be a function!' unless _.isFunction callback
    @initMatcher(ordersFrom).then (fromIndex2toIndex) =>
      if @options.showProgress
        @bar = new ProgressBar 'Updating order status [:bar] :percent done', { width: 50, total: _.size(fromIndex2toIndex) }
      @process(fromIndex2toIndex).then (msg) =>
        @returnResult true, msg, callback
      .fail (msg) =>
        @returnResult false, msg, callback
    .fail (msg) =>
      @returnResult false, msg, callback

  returnResult: (positiveFeedback, msg, callback) ->
    if @options.showProgress
      @bar.terminate()
    d =
      status: positiveFeedback
      msg: msg
    callback d

  initMatcher: (ordersFrom) ->
    @ordersFrom = ordersFrom
    deferred = Q.defer()
    @getOrders(@sync._rest).then (ordersTo) =>
      @ordersTo = ordersTo
      fromIndex2toIndex = {}
      for oTo,i in @ordersTo
        continue if oTo.exportedInfo
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
    @sync.buildActions(orderFrom, orderTo).update (error, response, body) =>
      if @options.showProgress
        @bar.tick()
      if error
        deferred.reject 'Error on updating order: ' + error
      else
        if response.statusCode is 200
          deferred.resolve 'Order status updated.'
        else if response.statusCode is 304
          deferred.resolve 'Order status update not necessary.'
        else
          deferred.reject 'Problem on updating order status (status: #{response.statusCode}): ' + body
    deferred.promise

module.exports = OrderStatusSync