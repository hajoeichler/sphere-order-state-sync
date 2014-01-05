_ = require('underscore')._
Config = require '../config'
OrderStateSync = require('../main').OrderStateSync
Q = require('q')

# Increase timeout
jasmine.getEnv().defaultTimeoutInterval = 20000

describe '#run', ->
  beforeEach (done) ->
    @sync = new OrderStateSync Config

    ensureChannel = (rest, channelKey, type) ->
      deferred = Q.defer()
      rest.GET "/channels?where=" + encodeURIComponent("key=\"#{channelKey}\""), (error, response, body) ->
        if error
          deferred.reject "Error: " + error
          return deferred.promise
        if response.statusCode == 200
          channels = JSON.parse(body).results
          if channels.length is 1
            deferred.resolve channels[0].id
            return deferred.promise
        # let's create the channel
        c =
          key: channelKey
          roles: [ 'OrderExport' ]
        rest.POST "/channels", JSON.stringify(c), (error, response, body) ->
          if error
            deferred.reject "Error: " + error
          else if response.statusCode == 201
            id = JSON.parse(body).id
            deferred.resolve id
          else
            deferred.reject "Problem: " + body
      deferred.promise
    ensureChannel(@sync.sync._rest, 'integrationTest').then (channelId) =>
      @channelId = channelId
      done()
    .fail (msg) ->
      console.log msg
      expect(false).toBe true
      done()

  it 'Nothing to do', (done) ->
    @sync.run [], (msg) ->
      expect(msg.status).toBe true
      expect(msg.message).toBe 'Nothing to do.'
      done()

  it 'update order', (done) ->
    unique = new Date().getTime()
    pt =
      name: "PT-#{unique}"
      description: 'bla'
    @sync.sync._rest.POST '/product-types', JSON.stringify(pt), (error, response, body) =>
      expect(response.statusCode).toBe 201
      pt = JSON.parse(body)
      p =
        productType:
          typeId: 'product-type'
          id: pt.id
        name:
          en: "P-#{unique}"
        slug:
          en: "p-#{unique}"
        masterVariant:
          sku: "sku-#{unique}"
      @sync.sync._rest.POST '/products', JSON.stringify(p), (error, response, body) =>
        expect(response.statusCode).toBe 201
        oFrom =
          id: "oFrom-#{unique}"
          orderState: 'Complete'
          lineItems: [ {
            sku: "sku-#{unique}"
            name:
              de: 'foo'
            taxRate:
              name: 'myTax'
              amount: 0.10
              includedInPrice: false
              country: 'DE'
            quantity: 1
            price:
              value:
                centAmount: 999
                currencyCode: 'EUR'
          } ]
          totalPrice:
            currencyCode: 'EUR'
            centAmount: 999
    
        oTo = {}
        _.extend(oTo, oFrom)
        oTo.orderState = 'Open'
          
        @sync.sync._rest.POST '/orders/import', JSON.stringify(oTo), (error, response, body) =>
          expect(response.statusCode).toBe 201
          order = JSON.parse(body)
          data =
            version: order.version
            actions: [
              action: 'updateExportInfo'
              channel:
                typeId: 'channel'
                id: @channelId
              exportedAt: '2000-01-01T01:01:01.000Z'
              externalId: oFrom.id
            ]
          @sync.sync._rest.POST "/orders/#{order.id}", JSON.stringify(data), (error, response, body) =>
            expect(response.statusCode).toBe 200
            @sync.run [oFrom], (msg) ->
              expect(msg.status).toBe true
              expect(msg.message).toBe 'Order state updated.'
              done()
