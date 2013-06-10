chai = require 'chai'
chai.should()
expect = chai.expect

ChildDaemon = require 'child-daemon'
zmq = require 'zmq'

describe 'ce-operation-hub', ->
  describe 'on start', ->
    beforeEach ->
      @ceFrontEnd = zmq.socket 'xreq'
      @order =
        account: 'Peter'
        bidCurrency: 'EUR'
        offerCurrency: 'BTC'
        bidPrice: '100'
        bidAmount: '50'        

    afterEach ->
      @ceFrontEnd.close()

    it 'should take parameters from the command line', (done) ->
      this.timeout 5000
      childDaemon = new ChildDaemon 'node', ['lib/src/index.js', '--bind-address', 'tcp://127.0.0.1:4001'], new RegExp 'ce-operation-hub started'
      childDaemon.start (error, matched) =>
        expect(error).to.not.be.ok
        @ceFrontEnd.connect 'tcp://127.0.0.1:4001'
        @ceFrontEnd.on 'message', =>
          args = Array.apply null, arguments
          args[0].toString().should.equal '123456'
          childDaemon.stop (error) =>
            expect(error).to.not.be.ok
            done()
        @ceFrontEnd.send ['123456', JSON.stringify @order]

    it 'should take parameters from a file', (done) ->
      this.timeout 5000
      childDaemon = new ChildDaemon 'node', ['lib/src/index.js', '--config', 'test/support/testConfig.json'], new RegExp 'ce-operation-hub started'
      childDaemon.start (error, matched) =>
        expect(error).to.not.be.ok
        @ceFrontEnd.connect 'tcp://127.0.0.1:4002'
        @ceFrontEnd.on 'message', =>
          args = Array.apply null, arguments
          args[0].toString().should.equal '123456'
          childDaemon.stop (error) =>
            expect(error).to.not.be.ok
            done()
        @ceFrontEnd.send ['123456', JSON.stringify @order]

    it 'should override parameters from a file with parameters from the command line', (done) ->
      this.timeout 5000
      childDaemon = new ChildDaemon 'node', ['lib/src/index.js', '--config', 'test/support/testConfig.json', '--bind-address', 'tcp://127.0.0.1:4003'], new RegExp 'ce-operation-hub started'
      childDaemon.start (error, matched) =>
        expect(error).to.not.be.ok
        @ceFrontEnd.connect 'tcp://127.0.0.1:4003'
        @ceFrontEnd.on 'message', =>
          args = Array.apply null, arguments
          args[0].toString().should.equal '123456'
          childDaemon.stop (error) =>
            expect(error).to.not.be.ok
            done()
        @ceFrontEnd.send ['123456', JSON.stringify @order]
