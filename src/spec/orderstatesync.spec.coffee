OrderStateSync = require('../main').OrderStateSync

describe 'OrderStateSync', ->
  it 'should throw error that there is no config', ->
    expect(-> new OrderStateSync()).toThrow new Error 'No configuration in options!'
    expect(-> new OrderStateSync({})).toThrow new Error 'No configuration in options!'

describe '#run', ->
  beforeEach ->
    c =
      project_key: 'x'
      client_id: 'y'
      client_secret: 'z'
    @orderStateSync = new OrderStateSync { config: c }

  it 'should throw error if callback is passed', ->
    expect(=> @orderStateSync.run()).toThrow new Error 'Callback must be a function!'

describe '#process', ->
  beforeEach ->
    c =
      project_key: '1'
      client_id: '2'
      client_secret: '3'
    @orderStateSync = new OrderStateSync { config: c }

  it 'nothing to do', (done) ->
    @orderStateSync.process({}).then (msg) ->
      expect(msg).toBe 'Nothing to do.'
      done()

  it 'update not necessary', (done) ->
    @orderStateSync.ordersFrom = [{ id: 'from-1', orderState: 'Open' }]
    @orderStateSync.ordersTo = [{ id: 'to-1', orderState: 'Open' }]
    @orderStateSync.process({ 0: 0 }).then (msg) ->
      expect(msg[0]).toBe 'Order state update not necessary.'
      done()

  it 'should update order', (done) ->
    spyOn(@orderStateSync.sync._rest, "POST").andCallFake((path, payload, callback) ->
      callback(null, {statusCode: 200}, null))

    @orderStateSync.ordersFrom = [{ id: 'from-1', orderState: 'Complete' }]
    @orderStateSync.ordersTo = [{ id: 'to-1', orderState: 'Open' }]
    @orderStateSync.process({ 0: 0 }).then (msg) =>
      expect(msg[0]).toBe 'Order state updated.'
      expectedAction =
        actions: [
          action: 'changeOrderState'
          orderState: 'Complete'
        ]
      expect(@orderStateSync.sync._rest.POST).toHaveBeenCalledWith("/orders/to-1", JSON.stringify(expectedAction), jasmine.any(Function))
      done()
    .fail (msg) ->
      expect(true).toBe false