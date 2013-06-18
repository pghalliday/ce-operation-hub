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
      operation = JSON.parse message
      operation.account.should.equal 'Peter'
      operation.id.should.equal 0
      order = operation.order
      order.bidCurrency.should.equal 'EUR'
      order.offerCurrency.should.equal 'BTC'
      order.bidPrice.should.equal '100'
      order.bidAmount.should.equal '50'
      operation.result = 'success'
      ceEngine.result.send JSON.stringify operation
    operation =
      account: 'Peter'
      order:
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
      ceFrontEnd.on 'message', (ref, message) =>
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
        childDaemon.stop (error) =>
          expect(error).to.not.be.ok
          ceFrontEnd.close()
          ceEngine.stream.close()
          ceEngine.result.close()
          done()
      ceFrontEnd.send ['123456', JSON.stringify operation]
