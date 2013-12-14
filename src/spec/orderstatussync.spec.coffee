OrderStatusSync = require('../main').OrderStatusSync

describe 'OrderStatusSync', ->
  it 'should throw error that there is no config', ->
    expect(-> new OrderStatusSync()).toThrow new Error 'No configuration in options!'
    expect(-> new OrderStatusSync({})).toThrow new Error 'No configuration in options!'

describe '#run', ->
  beforeEach ->
    c =
      project_key: 'x'
      client_id: 'y'
      client_secret: 'z'
    @orderStatusSync = new OrderStatusSync { config: c }

  it 'should throw error if callback is passed', ->
    expect(=> @orderStatusSync.run()).toThrow new Error 'Callback must be a function!'

describe '#process', ->
  beforeEach ->
    c =
      project_key: '1'
      client_id: '2'
      client_secret: '3'
    @orderStatusSync = new OrderStatusSync { config: c }

  it 'nothing to do', (done) ->
    @orderStatusSync.process({}).then (msg) ->
      expect(msg).toBe 'Nothing to do.'
      done()

  it 'update not necessary', (done) ->
    @orderStatusSync.ordersFrom = [{ id: 'from-1', orderState: 'Open' }]
    @orderStatusSync.ordersTo = [{ id: 'to-1', orderState: 'Open' }]
    @orderStatusSync.process({ 0: 0 }).then (msg) ->
      expect(msg[0]).toBe 'Order status update not necessary.'
      done()

  it 'should update order', (done) ->
    spyOn(@orderStatusSync.sync._rest, "POST").andCallFake((path, payload, callback) ->
      callback(null, {statusCode: 200}, null))

    @orderStatusSync.ordersFrom = [{ id: 'from-1', orderState: 'Complete' }]
    @orderStatusSync.ordersTo = [{ id: 'to-1', orderState: 'Open' }]
    @orderStatusSync.process({ 0: 0 }).then (msg) =>
      expect(msg[0]).toBe 'Order status updated.'
      expectedAction =
        actions: [
          action: 'changeOrderState'
          orderState: 'Complete'
        ]
      expect(@orderStatusSync.sync._rest.POST).toHaveBeenCalledWith("/orders/to-1", JSON.stringify(expectedAction), jasmine.any(Function))
      done()
    .fail (msg) ->
      expect(true).toBe false