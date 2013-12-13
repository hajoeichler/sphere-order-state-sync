_ = require('underscore')._
Config = require '../config'
OrderStatusSync = require('../main').OrderStatusSync
Q = require('q')

# Increase timeout
jasmine.getEnv().defaultTimeoutInterval = 3000

describe '#run', ->
  beforeEach ->
    @sync = new OrderStatusSync Config

  it 'Nothing to do', (done) ->
    @sync.run (msg) ->
      expect(msg.status).toBe true
      expect(msg.msg).toBe 'Nothing to do.'
      done()

  xit 'update order', (done) ->
    oFrom =
      orderStatus: 'Complete'
      totalPrice:
        currencyCode: 'EUR'
        centAmount: 999

    oTo = {}
    _.extend(oTo, oFrom)
    oTo.orderStatus = 'Open'
      
    @sync.restFrom.POST '/orders/import', JSON.stringify(oFrom), (error, response, body) =>
      console.log body
      order = JSON.parse(body)
      idFrom = order.id
      versionFrom = order.version
      @sync.restTo.POST '/orders/import', JSON.stringify(oTo), (error, response, body) =>
        console.log body
        idTo = JSON.parse(body).id
        data =
          version: versionFrom,
          actions: [
            action: 'updateExportInfo'
            exportedAt: '2000-01-01T01:01:01.000Z'
            externalId = idFrom
          ]
        @sync.restTo.POST "/orders/#{idTo}", JSON.stringify(data), (error, response, body) =>
          console.log body
          @sync.run (msg) ->
            console.log msg
            expect(msg.status).toBe true
            expect(msg.msg.length).toBe 1
            expect(msg.msg[0]).toBe 'Order status updated.'
            done()