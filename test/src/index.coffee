chai = require 'chai'
chai.should()
expect = chai.expect

ChildDaemon = require 'child-daemon'
zmq = require 'zmq'

Operation = require('currency-market').Operation
Engine = require('currency-market').Engine
Delta = require('currency-market').Delta
Amount = require('currency-market').Amount

COMMISSION_REFERENCE = '0.1%'
COMMISSION_RATE = new Amount '0.001'
COMMISSION_ACCOUNT = 'commission'

describe 'ce-operation-hub', ->
  it 'should take parameters from a file', (done) ->
    this.timeout 5000
    startTime = Date()
    engine = new Engine
      commission:
        account: COMMISSION_ACCOUNT
        calculate: (params) ->
          amount: params.amount.multiply COMMISSION_RATE
          reference: COMMISSION_REFERENCE
    ceFrontEnd = zmq.socket 'dealer'
    ceEngine =
      stream: zmq.socket 'sub'
      history: zmq.socket 'dealer'
      result: zmq.socket 'push'
    ceEngine.stream.subscribe ''
    ceEngine.stream.on 'message', (message) =>
      operation = new Operation
        json: message
      operation.reference.should.equal '550e8400-e29b-41d4-a716-446655440000'
      operation.account.should.equal 'Peter'
      operation.sequence.should.equal 0
      operation.timestamp.should.be.at.least @startTime
      operation.timestamp.should.be.at.most Date.now()
      deposit = operation.deposit
      deposit.currency.should.equal 'BTC'
      deposit.amount.compareTo(new Amount '5000').should.equal 0
      ceEngine.result.send JSON.stringify engine.apply operation
    operation = new Operation
      reference: '550e8400-e29b-41d4-a716-446655440000'
      account: 'Peter'
      deposit:
        currency: 'BTC'
        amount: new Amount '5000'
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
        response = JSON.parse message
        operation = new Operation
          exported: response.operation
        delta = new Delta
          exported: response.delta
        operation.reference.should.equal '550e8400-e29b-41d4-a716-446655440000'
        operation.account.should.equal 'Peter'
        operation.sequence.should.equal 0
        operation.timestamp.should.be.at.least @startTime
        operation.timestamp.should.be.at.most Date.now()
        deposit = operation.deposit
        deposit.currency.should.equal 'BTC'
        deposit.amount.compareTo(new Amount '5000').should.equal 0
        delta.sequence.should.equal 0
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
        childDaemon.stop (error) =>
          expect(error).to.not.be.ok
          ceFrontEnd.close()
          ceEngine.stream.close()
          ceEngine.history.close()
          ceEngine.result.close()
          done()
      ceFrontEnd.send [JSON.stringify operation]
