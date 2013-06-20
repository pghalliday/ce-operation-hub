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
      history: zmq.socket 'xreq'
      result: zmq.socket 'push'
    ceEngine.stream.subscribe ''
    ceEngine.stream.on 'message', (message) =>
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
      ceEngine.result.send JSON.stringify operation
    operation =
      reference: '550e8400-e29b-41d4-a716-446655440000'
      account: 'Peter'
      submit:
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
      ceEngine.history.connect 'tcp://localhost:7002'
      ceEngine.result.connect 'tcp://localhost:7003'
      ceFrontEnd.on 'message', (message) =>
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
        childDaemon.stop (error) =>
          expect(error).to.not.be.ok
          ceFrontEnd.close()
          ceEngine.stream.close()
          ceEngine.history.close()
          ceEngine.result.close()
          done()
      ceFrontEnd.send [JSON.stringify operation]
