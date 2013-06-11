chai = require 'chai'
chai.should()
expect = chai.expect

Server = require '../../src/Server'

zmq = require 'zmq'

describe 'Server', ->
  describe '#stop', ->
    it 'should not error if the server has not been started', (done) ->
      server = new Server
        ceFrontEndXReply: 'tcp://*:8000'
        ceEnginePublisher: 'tcp://*:8001'
        ceEnginePull: 'tcp://*:8002'
      server.stop (error) ->
        expect(error).to.not.be.ok
        done()

  describe '#start', ->
    it 'should start and be stoppable', (done) ->
      server = new Server
        ceFrontEndXReply: 'tcp://*:8000'
        ceEnginePublisher: 'tcp://*:8001'
        ceEnginePull: 'tcp://*:8002'
      server.start (error) ->
        expect(error).to.not.be.ok
        server.stop (error) ->
          expect(error).to.not.be.ok
          done()

    it 'should error if it cannot bind to ceFrontEndXReply address', (done) ->
      server = new Server
        ceFrontEndXReply: 'tcp://invalid:8000'
        ceEnginePublisher: 'tcp://*:8001'
        ceEnginePull: 'tcp://*:8002'
      server.start (error) ->
        error.message.should.equal 'No such device'
        done()

    it 'should error if it cannot bind to ceEnginePublisher address', (done) ->
      server = new Server
        ceFrontEndXReply: 'tcp://*:8000'
        ceEnginePublisher: 'tcp://invalid:8001'
        ceEnginePull: 'tcp://*:8002'
      server.start (error) ->
        error.message.should.equal 'No such device'
        done()

    it 'should error if it cannot bind to ceEnginePull address', (done) ->
      server = new Server
        ceFrontEndXReply: 'tcp://*:8000'
        ceEnginePublisher: 'tcp://*:8001'
        ceEnginePull: 'tcp://invalid:8002'
      server.start (error) ->
        error.message.should.equal 'No such device'
        done()

  describe 'when started', ->
    beforeEach (done) ->
      @ceFrontEndXRequest = zmq.socket 'xreq'
      @ceEngineSubscriber = zmq.socket 'sub'
      @ceEnginePush = zmq.socket 'push'
      @ceEngineSubscriber.subscribe ''
      @ceEngineSubscriber.on 'message', (message) =>
        order = JSON.parse message
        order.bidCurrency.should.equal 'EUR'
        order.offerCurrency.should.equal 'BTC'
        order.bidPrice.should.equal '100'
        order.bidAmount.should.equal '50'
        order.account.should.equal 'Peter'
        order.id.should.equal 0
        order.engineTest = 'this is a test'
        @ceEnginePush.send JSON.stringify order
      @order =
        account: 'Peter'
        bidCurrency: 'EUR'
        offerCurrency: 'BTC'
        bidPrice: '100'
        bidAmount: '50'        
      @server = new Server
        ceFrontEndXReply: 'tcp://*:8000'
        ceEnginePublisher: 'tcp://*:8001'
        ceEnginePull: 'tcp://*:8002'
      @server.start (error) =>
        @ceFrontEndXRequest.connect 'tcp://localhost:8000'
        @ceEngineSubscriber.connect 'tcp://localhost:8001'
        @ceEnginePush.connect 'tcp://localhost:8002'
        done()

    afterEach (done) ->
      @ceFrontEndXRequest.close()
      @ceEngineSubscriber.close()
      @ceEnginePush.close()
      @server.stop done

    it 'should add an ID to submitted orders and publish them to the ce-engine instances', (done) ->
      @ceFrontEndXRequest.on 'message', =>
        args = Array.apply null, arguments
        args[0].toString().should.equal '123456'
        order = JSON.parse args[1]
        order.bidCurrency.should.equal 'EUR'
        order.offerCurrency.should.equal 'BTC'
        order.bidPrice.should.equal '100'
        order.bidAmount.should.equal '50'
        order.account.should.equal 'Peter'
        order.id.should.equal 0
        order.engineTest.should.equal 'this is a test'
        done()
      @ceFrontEndXRequest.send ['123456', JSON.stringify @order]
