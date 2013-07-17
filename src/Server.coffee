zmq = require 'zmq'
Operation = require('currency-market').Operation
Delta = require('currency-market').Delta

module.exports = class Server
  constructor: (@options) ->
    @currentSequence = 0
    @history = []
    @ceFrontEnd = zmq.socket 'router'
    @ceEngine = 
      stream: zmq.socket 'pub'
      history: zmq.socket 'router'
      result: zmq.socket 'pull'
    @ceFrontEnd.on 'message', (ref, message) =>
      response =
        operation: message.toString()
      try
        response.operation = new Operation
          json: message
      catch error
        response.error = error.toString()
      if response.error
        @ceFrontEnd.send [ref, JSON.stringify response]
      else
        sequence = @currentSequence++
        response.operation.accept
          sequence: sequence
          timestamp: Date.now()
        @history.push response.operation
        replyHandler = (message) =>
          engineResponse = JSON.parse message
          operation = engineResponse.operation
          if operation
            if operation.sequence == sequence
              clearTimeout timeout
              delta = engineResponse.delta
              if delta
                response.delta = new Delta
                  exported: delta
              else
                response.error = engineResponse.error
              @ceEngine.result.removeListener 'message', replyHandler
              @ceFrontEnd.send [ref, JSON.stringify response]
        @ceEngine.result.on 'message', replyHandler
        @ceEngine.stream.send JSON.stringify response.operation
        timeout = setTimeout =>
          @ceEngine.result.removeListener 'message', replyHandler
          response.pending = true
          @ceFrontEnd.send [ref, JSON.stringify response]
        , @options['ce-engine'].timeout
    @ceEngine.history.on 'message', (ref, message) =>
      response =
        from: message.toString()
      try
        response.from = JSON.parse message
      catch error
        response.error = error.toString()
      if response.error
        @ceEngine.history.send [ref, JSON.stringify response]
      else
        if typeof response.from == 'number'
          if response.from > @currentSequence 
            response.error = (new Error 'start ID must be the next ID or earlier').toString()
            @ceEngine.history.send [ref, JSON.stringify response]
          else
            response.history = @history.slice response.from
            @ceEngine.history.send [ref, JSON.stringify response]
        else
          response.error = (new Error 'invalid start ID').toString()
          @ceEngine.history.send [ref, JSON.stringify response]

  stop: (callback) =>
    @ceFrontEnd.close()
    @ceEngine.stream.close()
    @ceEngine.history.close()
    @ceEngine.result.close()
    callback()

  start: (callback) =>
    @ceFrontEnd.bind 'tcp://*:' + @options['ce-front-end'].submit, (error) =>
      if error
        callback error
      else
        @ceEngine.stream.bind 'tcp://*:' + @options['ce-engine'].stream, (error) =>
          if error
            @ceFrontEnd.close()
            callback error
          else
            @ceEngine.history.bind 'tcp://*:' + @options['ce-engine'].history, (error) =>
              if error
                @ceFrontEnd.close()
                @ceEngine.stream.close()
                callback error
              else
                @ceEngine.result.bind 'tcp://*:' + @options['ce-engine'].result, (error) =>
                  if error
                    @ceFrontEnd.close()
                    @ceEngine.stream.close()
                    @ceEngine.history.close()
                    callback error
                  else
                    callback()
