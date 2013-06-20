chai = require 'chai'
chai.should()
expect = chai.expect

Server = require '../../src/Server'

zmq = require 'zmq'
ports = require '../support/ports'

describe 'Server', ->
  describe '#stop', ->
    it 'should not error if the server has not been started', (done) ->
      server = new Server
        'ce-front-end':
          submit: ports()
        'ce-engine':
          stream: ports()
          history: ports()
          result: ports()
          timeout: 2000
      server.stop (error) ->
        expect(error).to.not.be.ok
        done()

  describe '#start', ->
    it 'should start and be stoppable', (done) ->
      server = new Server
        'ce-front-end':
          submit: ports()
        'ce-engine':
          stream: ports()
          history: ports()
          result: ports()
          timeout: 2000
      server.start (error) ->
        expect(error).to.not.be.ok
        server.stop (error) ->
          expect(error).to.not.be.ok
          done()

    it 'should error if it cannot bind to the ce-front-end address', (done) ->
      server = new Server
        'ce-front-end':
          submit: 'invalid'
        'ce-engine':
          stream: ports()
          history: ports()
          result: ports()
          timeout: 2000
      server.start (error) ->
        error.message.should.equal 'Invalid argument'
        done()

    it 'should error if it cannot bind to the ce-engine stream port', (done) ->
      server = new Server
        'ce-front-end':
          submit: ports()
        'ce-engine':
          stream: 'invalid'
          history: ports()
          result: ports()
          timeout: 2000
      server.start (error) ->
        error.message.should.equal 'Invalid argument'
        done()

    it.skip 'should error if it cannot bind to the ce-engine history port', (done) ->
      server = new Server
        'ce-front-end':
          submit: ports()
        'ce-engine':
          stream: ports()
          history: 'invalid'
          result: ports()
          timeout: 2000
      server.start (error) ->
        error.message.should.equal 'Invalid argument'
        done()

    it 'should error if it cannot bind to the ce-engine result port', (done) ->
      server = new Server
        'ce-front-end':
          submit: ports()
        'ce-engine':
          stream: ports()
          history: ports()
          result: 'invalid'
          timeout: 2000
      server.start (error) ->
        error.message.should.equal 'Invalid argument'
        done()

  describe 'when started', ->
    beforeEach (done) ->
      @ceEngineDelay = 0
      @ceFrontEnd = zmq.socket 'xreq'
      @ceEngine = 
        stream: zmq.socket 'sub'
        result: zmq.socket 'push'
      @ceEngine.stream.subscribe ''
      @ceEngine.stream.on 'message', (message) =>
        operation = JSON.parse message
        operation.reference.should.equal '550e8400-e29b-41d4-a716-446655440000'
        operation.account.should.equal 'Peter'
        operation.id.should.equal 0
        submit = operation.submit
        submit.bidCurrency.should.equal 'EUR'
        submit.offerCurrency.should.equal 'BTC'
        submit.bidPrice.should.equal '100'
        submit.bidAmount.should.equal '50'
        operation.result = 'success'
        @ceEngineTimeout = setTimeout =>
          @ceEngine.result.send JSON.stringify operation
        , @ceEngineDelay
      @operation =
        reference: '550e8400-e29b-41d4-a716-446655440000'
        account: 'Peter'
        submit:
          bidCurrency: 'EUR'
          offerCurrency: 'BTC'
          bidPrice: '100'
          bidAmount: '50'
      ceFrontEndPort = ports()
      ceEngineStreamPort = ports()
      ceEngineHistoryPort = ports()
      ceEngineResultPort = ports()
      @server = new Server
        'ce-front-end':
          submit: ceFrontEndPort
        'ce-engine':
          stream: ceEngineStreamPort
          history: ceEngineHistoryPort
          result: ceEngineResultPort
          timeout: 250
      @server.start (error) =>
        @ceFrontEnd.connect 'tcp://localhost:' + ceFrontEndPort
        @ceEngine.stream.connect 'tcp://localhost:' + ceEngineStreamPort
        @ceEngine.result.connect 'tcp://localhost:' + ceEngineResultPort
        done()

    afterEach (done) ->
      clearTimeout @ceEngineTimeout
      @ceFrontEnd.close()
      @ceEngine.stream.close()
      @ceEngine.result.close()
      @server.stop done

    it 'should add an ID to submitted operations and publish them to the ce-engine instances', (done) ->
      @ceFrontEnd.on 'message', (message) =>
        operation = JSON.parse message
        operation.reference.should.equal '550e8400-e29b-41d4-a716-446655440000'
        operation.account.should.equal 'Peter'
        operation.id.should.equal 0
        operation.result.should.equal 'success'
        submit = operation.submit
        submit.bidCurrency.should.equal 'EUR'
        submit.offerCurrency.should.equal 'BTC'
        submit.bidPrice.should.equal '100'
        submit.bidAmount.should.equal '50'
        done()
      @ceFrontEnd.send JSON.stringify @operation

    it 'should respond with an error if the submitted operation cannot be parsed', (done) ->
      @ceFrontEnd.on 'message', (message) =>
        operation = JSON.parse message
        operation.result.should.equal 'error: invalid request data'
        done()
      @ceFrontEnd.send 'invalid JSON'

    it 'should timeout and respond with a pending result if no ce-engine instance responds within the configured timeout period', (done) ->
      @ceEngineDelay = 500
      @ceFrontEnd.on 'message', (message) =>
        operation = JSON.parse message
        operation.reference.should.equal '550e8400-e29b-41d4-a716-446655440000'
        operation.account.should.equal 'Peter'
        operation.id.should.equal 0
        operation.result.should.equal 'pending'
        submit = operation.submit
        submit.bidCurrency.should.equal 'EUR'
        submit.offerCurrency.should.equal 'BTC'
        submit.bidPrice.should.equal '100'
        submit.bidAmount.should.equal '50'
        done()
      @ceFrontEnd.send JSON.stringify @operation
