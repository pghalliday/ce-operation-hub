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
          result: ports()
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
          result: ports()
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
          result: ports()
      server.start (error) ->
        error.message.should.equal 'Invalid argument'
        done()

    it 'should error if it cannot bind to the ce-engine stream port', (done) ->
      server = new Server
        'ce-front-end':
          submit: ports()
        'ce-engine':
          stream: 'invalid'
          result: ports()
      server.start (error) ->
        error.message.should.equal 'Invalid argument'
        done()

    it 'should error if it cannot bind to the ce-engine result port', (done) ->
      server = new Server
        'ce-front-end':
          submit: ports()
        'ce-engine':
          stream: ports()
          result: 'invalid'
      server.start (error) ->
        error.message.should.equal 'Invalid argument'
        done()

  describe 'when started', ->
    beforeEach (done) ->
      @ceFrontEnd = zmq.socket 'xreq'
      @ceEngine = 
        stream: zmq.socket 'sub'
        result: zmq.socket 'push'
      @ceEngine.stream.subscribe ''
      @ceEngine.stream.on 'message', (message) =>
        operation = JSON.parse message
        operation.account.should.equal 'Peter'
        operation.id.should.equal 0
        order = operation.order
        order.bidCurrency.should.equal 'EUR'
        order.offerCurrency.should.equal 'BTC'
        order.bidPrice.should.equal '100'
        order.bidAmount.should.equal '50'
        operation.result = 'success'
        @ceEngine.result.send JSON.stringify operation
      @operation =
        account: 'Peter'
        order:
          bidCurrency: 'EUR'
          offerCurrency: 'BTC'
          bidPrice: '100'
          bidAmount: '50'
      ceFrontEndPort = ports()
      ceEngineStreamPort = ports()
      ceEngineResultPort = ports()
      @server = new Server
        'ce-front-end':
          submit: ceFrontEndPort
        'ce-engine':
          stream: ceEngineStreamPort
          result: ceEngineResultPort
      @server.start (error) =>
        @ceFrontEnd.connect 'tcp://localhost:' + ceFrontEndPort
        @ceEngine.stream.connect 'tcp://localhost:' + ceEngineStreamPort
        @ceEngine.result.connect 'tcp://localhost:' + ceEngineResultPort
        done()

    afterEach (done) ->
      @ceFrontEnd.close()
      @ceEngine.stream.close()
      @ceEngine.result.close()
      @server.stop done

    it 'should add an ID to submitted operations and publish them to the ce-engine instances', (done) ->
      @ceFrontEnd.on 'message', (ref, message) =>
        ref.toString().should.equal '123456'
        operation = JSON.parse message
        operation.account.should.equal 'Peter'
        operation.id.should.equal 0
        operation.result.should.equal 'success'
        order = operation.order
        order.bidCurrency.should.equal 'EUR'
        order.offerCurrency.should.equal 'BTC'
        order.bidPrice.should.equal '100'
        order.bidAmount.should.equal '50'
        done()
      @ceFrontEnd.send ['123456', JSON.stringify @operation]

    it.skip 'should timeout if no ce-engine instance responds within the configured timeout period', (done) ->
      # TODO
      done()