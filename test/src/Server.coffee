chai = require 'chai'
chai.should()
expect = chai.expect

Server = require '../../src/Server'

zmq = require 'zmq'

describe 'Server', ->
  describe '#stop', ->
    it 'should not error if the server has not been started', (done) ->
      server = new Server
        bindAddress: 'tcp://127.0.0.1:4000'
      server.stop (error) ->
        expect(error).to.not.be.ok
        done()

  describe '#start', ->
    it 'should start and be stoppable', (done) ->
      server = new Server
        bindAddress: 'tcp://127.0.0.1:8000'
      server.start (error) ->
        expect(error).to.not.be.ok
        server.stop (error) ->
          expect(error).to.not.be.ok
          done()

  describe 'when started', ->
    beforeEach (done) ->
      @ceFrontEnd = zmq.socket 'xreq'
      @order =
        account: 'Peter'
        bidCurrency: 'EUR'
        offerCurrency: 'BTC'
        bidPrice: '100'
        bidAmount: '50'        
      @server = new Server
        bindAddress: 'tcp://127.0.0.1:8000'
      @server.start done

    afterEach (done) ->
      @ceFrontEnd.close()
      @server.stop done

    it 'should add an ID to submitted orders', (done) ->
      @ceFrontEnd.connect 'tcp://127.0.0.1:8000'
      @ceFrontEnd.on 'message', =>
        args = Array.apply null, arguments
        args[0].toString().should.equal '123456'
        order = JSON.parse args[1]
        order.bidCurrency.should.equal 'EUR'
        order.offerCurrency.should.equal 'BTC'
        order.bidPrice.should.equal '100'
        order.bidAmount.should.equal '50'
        order.account.should.equal 'Peter'
        order.id.should.equal '654321'
        done()
      @ceFrontEnd.send ['123456', JSON.stringify @order]
