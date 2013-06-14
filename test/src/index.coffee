chai = require 'chai'
chai.should()
expect = chai.expect

ChildDaemon = require 'child-daemon'
zmq = require 'zmq'

describe 'ce-operation-hub', ->
  it 'should take parameters from a file', (done) ->
    this.timeout 5000
    ceFrontEnd = zmq.socket 'xreq'
    ceEngine =
      stream: zmq.socket 'sub'
      result: zmq.socket 'push'
    ceEngine.stream.subscribe ''
    ceEngine.stream.on 'message', (message) =>
      order = JSON.parse message
      order.bidCurrency.should.equal 'EUR'
      order.offerCurrency.should.equal 'BTC'
      order.bidPrice.should.equal '100'
      order.bidAmount.should.equal '50'
      order.account.should.equal 'Peter'
      order.id.should.equal 0
      order.engineTest = 'this is a test'
      ceEngine.result.send JSON.stringify order
    order =
      account: 'Peter'
      bidCurrency: 'EUR'
      offerCurrency: 'BTC'
      bidPrice: '100'
      bidAmount: '50'        
    childDaemon = new ChildDaemon 'node', [
      'lib/src/index.js',
      '--config',
      'test/support/testConfig.json'
    ], new RegExp 'ce-operation-hub started'
    childDaemon.start (error, matched) =>
      expect(error).to.not.be.ok
      ceFrontEnd.connect 'tcp://localhost:7000'
      ceEngine.stream.connect 'tcp://localhost:7001'
      ceEngine.result.connect 'tcp://localhost:7002'
      ceFrontEnd.on 'message', =>
        args = Array.apply null, arguments
        args[0].toString().should.equal '123456'
        childDaemon.stop (error) =>
          expect(error).to.not.be.ok
          ceFrontEnd.close()
          ceEngine.stream.close()
          ceEngine.result.close()
          done()
      ceFrontEnd.send ['123456', JSON.stringify order]
