chai = require 'chai'
chai.should()
expect = chai.expect

Server = require '../../src/Server'

zmq = require 'zmq'
ports = require '../support/ports'

Operation = require('currency-market').Operation
Engine = require('currency-market').Engine
Delta = require('currency-market').Delta
Amount = require('currency-market').Amount

COMMISSION_REFERENCE = '0.1%'
COMMISSION_RATE = new Amount '0.001'
COMMISSION_ACCOUNT = 'commission'

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

    it 'should error if it cannot bind to the ce-engine history port', (done) ->
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
      @engine = new Engine
        commission:
          account: COMMISSION_ACCOUNT
          calculate: (params) ->
            amount: params.amount.multiply COMMISSION_RATE
            reference: COMMISSION_REFERENCE
      @ceEngineDelay = 0
      @ceFrontEnd = zmq.socket 'dealer'
      @ceEngine = 
        stream: zmq.socket 'sub'
        history: zmq.socket 'dealer'
        result: zmq.socket 'push'
      @ceEngine.stream.subscribe ''
      @ceEngine.stream.on 'message', (message) =>
        operation = new Operation
          json: message
        operation.reference.should.equal '550e8400-e29b-41d4-a716-446655440000'
        operation.account.should.equal 'Peter'
        operation.sequence.should.be.a 'number'
        operation.timestamp.should.be.at.least @startTime
        operation.timestamp.should.be.at.most Date.now()
        deposit = operation.deposit
        deposit.currency.should.equal 'BTC'
        deposit.amount.compareTo(new Amount '5000').should.equal 0
        @ceEngineTimeout = setTimeout =>
          @ceEngine.result.send JSON.stringify @engine.apply operation
        , @ceEngineDelay
      @operation = new Operation
        reference: '550e8400-e29b-41d4-a716-446655440000'
        account: 'Peter'
        deposit:
          currency: 'BTC'
          amount: new Amount '5000'
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
        @ceEngine.history.connect 'tcp://localhost:' + ceEngineHistoryPort
        @ceEngine.result.connect 'tcp://localhost:' + ceEngineResultPort
        done()

    afterEach (done) ->
      clearTimeout @ceEngineTimeout
      @ceFrontEnd.close()
      @ceEngine.stream.close()
      @ceEngine.history.close()
      @ceEngine.result.close()
      @server.stop done

    it 'should add a sequence number and timestamp to submitted operations and publish them to the ce-engine instances', (done) ->
      @startTime = Date.now()
      @ceFrontEnd.on 'message', (message) =>
        response = JSON.parse message
        operation = new Operation
          exported: response.operation
        operation.reference.should.equal '550e8400-e29b-41d4-a716-446655440000'
        operation.account.should.equal 'Peter'
        operation.sequence.should.equal 0
        operation.timestamp.should.be.at.least @startTime
        operation.timestamp.should.be.at.most Date.now()
        deposit = operation.deposit
        deposit.currency.should.equal 'BTC'
        deposit.amount.compareTo(new Amount '5000').should.equal 0
        delta = new Delta
          exported: response.delta
        operation = delta.operation
        operation.reference.should.equal '550e8400-e29b-41d4-a716-446655440000'
        operation.account.should.equal 'Peter'
        operation.sequence.should.equal 0
        operation.timestamp.should.be.at.least @startTime
        operation.timestamp.should.be.at.most Date.now()
        deposit = operation.deposit
        deposit.currency.should.equal 'BTC'
        deposit.amount.compareTo(new Amount '5000').should.equal 0
        result = delta.result
        result.funds.compareTo(new Amount '5000').should.equal 0
        done()
      @ceFrontEnd.send JSON.stringify @operation

    it 'should respond with an error if the submitted operation cannot be parsed', (done) ->
      @ceFrontEnd.on 'message', (message) =>
        response = JSON.parse message
        response.operation.should.equal 'invalid JSON'
        response.error.should.equal 'SyntaxError: Unexpected token i'
        done()
      @ceFrontEnd.send 'invalid JSON'

    it 'should timeout and respond with a pending result if no ce-engine instance responds within the configured timeout period', (done) ->
      @ceEngineDelay = 500
      @startTime = Date.now()
      @ceFrontEnd.on 'message', (message) =>
        response = JSON.parse message
        response.pending.should.be.true
        operation = new Operation
          exported: response.operation
        operation.reference.should.equal '550e8400-e29b-41d4-a716-446655440000'
        operation.account.should.equal 'Peter'
        operation.sequence.should.equal 0
        operation.timestamp.should.be.at.least @startTime
        operation.timestamp.should.be.at.most Date.now()
        deposit = operation.deposit
        deposit.currency.should.equal 'BTC'
        deposit.amount.compareTo(new Amount '5000').should.equal 0
        done()
      @ceFrontEnd.send JSON.stringify @operation

    it 'should respond with an error when the history is requested with an unparsable start sequence number for the list', (done) ->
      @ceEngine.history.on 'message', (message) =>
        response = JSON.parse message
        response.from.should.equal ''
        response.error.should.equal 'SyntaxError: Unexpected end of input'
        done()
      @ceEngine.history.send ''

    it 'should respond with an error when the history is requested with an invalid start sequence number for the list', (done) ->
      @ceEngine.history.on 'message', (message) =>
        response = JSON.parse message
        response.from.should.equal 'hello'
        response.error.should.equal 'Error: invalid start ID'
        done()
      @ceEngine.history.send '"hello"'

    it 'should respond with an error when the history is requested with a start sequence number that is not next or earlier', (done) ->
      @ceEngine.history.on 'message', (message) =>
        response = JSON.parse message
        response.from.should.equal 3
        response.error.should.equal 'Error: start ID must be the next ID or earlier'
        done()
      secondOperation = (message) =>
        @ceEngine.history.send '3'
      firstOperation = (message) =>
        @ceFrontEnd.removeListener 'message', firstOperation
        @ceFrontEnd.on 'message', secondOperation
        @ceFrontEnd.send JSON.stringify @operation
      @ceFrontEnd.on 'message', firstOperation
      @ceFrontEnd.send JSON.stringify @operation

    it 'should respond with an empty list when the history is requested with a start sequence number that is next', (done) ->
      @ceEngine.history.on 'message', (message) =>
        response = JSON.parse message
        response.from.should.equal 2
        response.history.should.deep.equal []
        done()
      secondOperation = (message) =>
        @ceEngine.history.send '2'
      firstOperation = (message) =>
        @ceFrontEnd.removeListener 'message', firstOperation
        @ceFrontEnd.on 'message', secondOperation
        @ceFrontEnd.send JSON.stringify @operation
      @ceFrontEnd.on 'message', firstOperation
      @ceFrontEnd.send JSON.stringify @operation

    it 'should respond with a list of the last operations when requested with a start sequence number for the list', (done) ->
      @startTime = Date.now()
      @ceEngine.history.on 'message', (message) =>
        response = JSON.parse message
        response.from.should.equal 0
        response.history.should.have.length 2
        operation = new Operation
          exported: response.history[0]
        operation.reference.should.equal '550e8400-e29b-41d4-a716-446655440000'
        operation.account.should.equal 'Peter'
        operation.sequence.should.equal 0
        operation.timestamp.should.be.at.least @startTime
        operation.timestamp.should.be.at.most Date.now()
        deposit = operation.deposit
        deposit.currency.should.equal 'BTC'
        deposit.amount.compareTo(new Amount '5000').should.equal 0
        operation = new Operation 
          exported: response.history[1]
        operation.reference.should.equal '550e8400-e29b-41d4-a716-446655440000'
        operation.account.should.equal 'Peter'
        operation.sequence.should.equal 1
        operation.timestamp.should.be.at.least @startTime
        operation.timestamp.should.be.at.most Date.now()
        deposit = operation.deposit
        deposit.currency.should.equal 'BTC'
        deposit.amount.compareTo(new Amount '5000').should.equal 0
        done()
      secondOperation = (message) =>
        @ceEngine.history.send '0'
      firstOperation = (message) =>
        @ceFrontEnd.removeListener 'message', firstOperation
        @ceFrontEnd.on 'message', secondOperation
        @ceFrontEnd.send JSON.stringify @operation
      @ceFrontEnd.on 'message', firstOperation
      @ceFrontEnd.send JSON.stringify @operation
