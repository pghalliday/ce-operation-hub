chai = require 'chai'
chai.should()
expect = chai.expect

ChildDaemon = require 'child-daemon'
zmq = require 'zmq'

describe 'ce-operation-hub', ->
  describe 'on start', ->
    beforeEach ->
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

    afterEach ->
      @ceFrontEndXRequest.close()
      @ceEngineSubscriber.close()
      @ceEnginePush.close()

    it 'should take parameters from the command line', (done) ->
      this.timeout 5000
      childDaemon = new ChildDaemon 'node', [
        'lib/src/index.js',
        '--ce-front-end-xreply',
        'tcp://*:5000',
        '--ce-engine-publisher',
        'tcp://*:5001',
        '--ce-engine-pull',
        'tcp://*:5002'
      ], new RegExp 'ce-operation-hub started'
      childDaemon.start (error, matched) =>
        expect(error).to.not.be.ok
        @ceFrontEndXRequest.connect 'tcp://localhost:5000'
        @ceEngineSubscriber.connect 'tcp://localhost:5001'
        @ceEnginePush.connect 'tcp://localhost:5002'
        @ceFrontEndXRequest.on 'message', =>
          args = Array.apply null, arguments
          args[0].toString().should.equal '123456'
          childDaemon.stop (error) =>
            expect(error).to.not.be.ok
            done()
        @ceFrontEndXRequest.send ['123456', JSON.stringify @order]

    it 'should take parameters from a file', (done) ->
      this.timeout 5000
      childDaemon = new ChildDaemon 'node', [
        'lib/src/index.js',
        '--config',
        'test/support/testConfig.json'
      ], new RegExp 'ce-operation-hub started'
      childDaemon.start (error, matched) =>
        expect(error).to.not.be.ok
        @ceFrontEndXRequest.connect 'tcp://localhost:6000'
        @ceEngineSubscriber.connect 'tcp://localhost:6001'
        @ceEnginePush.connect 'tcp://localhost:6002'
        @ceFrontEndXRequest.on 'message', =>
          args = Array.apply null, arguments
          args[0].toString().should.equal '123456'
          childDaemon.stop (error) =>
            expect(error).to.not.be.ok
            done()
        @ceFrontEndXRequest.send ['123456', JSON.stringify @order]

    it 'should override parameters from a file with parameters from the command line', (done) ->
      this.timeout 5000
      childDaemon = new ChildDaemon 'node', [
        'lib/src/index.js',
        '--config',
        'test/support/testConfig.json',
        '--ce-front-end-xreply',
        'tcp://*:7000',
        '--ce-engine-publisher',
        'tcp://*:7001',
        '--ce-engine-pull',
        'tcp://*:7002'
      ], new RegExp 'ce-operation-hub started'
      childDaemon.start (error, matched) =>
        expect(error).to.not.be.ok
        @ceFrontEndXRequest.connect 'tcp://localhost:7000'
        @ceEngineSubscriber.connect 'tcp://localhost:7001'
        @ceEnginePush.connect 'tcp://localhost:7002'
        @ceFrontEndXRequest.on 'message', =>
          args = Array.apply null, arguments
          args[0].toString().should.equal '123456'
          childDaemon.stop (error) =>
            expect(error).to.not.be.ok
            done()
        @ceFrontEndXRequest.send ['123456', JSON.stringify @order]
