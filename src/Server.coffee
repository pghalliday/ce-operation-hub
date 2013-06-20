zmq = require 'zmq'

module.exports = class Server
  constructor: (@options) ->
    @currentSequence = 0
    @history = []
    @ceFrontEnd = zmq.socket 'xrep'
    @ceFrontEnd.setsockopt 'linger', 0
    @ceEngine = 
      stream: zmq.socket 'pub'
      history: zmq.socket 'xrep'
      result: zmq.socket 'pull'
    @ceEngine.stream.setsockopt 'linger', 0
    @ceEngine.history.setsockopt 'linger', 0
    @ceEngine.result.setsockopt 'linger', 0
    @ceFrontEnd.on 'message', (ref, message) =>
      isMessageInvalid = false
      try
        operation = JSON.parse message
      catch
        isMessageInvalid = true
      if isMessageInvalid
        operation = 
          result: 'error: invalid request data'
        @ceFrontEnd.send [ref, JSON.stringify operation]
      else
        sequence = @currentSequence++
        operation.sequence = sequence
        operation.timestamp = Date.now()
        @history.push operation
        replyHandler = (message) =>
          operation = JSON.parse message
          if operation.sequence == sequence
            clearTimeout timeout
            @ceEngine.result.removeListener 'message', replyHandler
            @ceFrontEnd.send [ref, JSON.stringify operation]
        @ceEngine.result.on 'message', replyHandler
        @ceEngine.stream.send JSON.stringify operation
        timeout = setTimeout =>
          @ceEngine.result.removeListener 'message', replyHandler
          operation.result = 'pending'
          @ceFrontEnd.send [ref, JSON.stringify operation]
        , @options['ce-engine'].timeout
    @ceEngine.history.on 'message', (ref, message) =>
      isMessageInvalid = false
      try
        startSequence = JSON.parse message
      catch
        isMessageInvalid = true
      if isMessageInvalid
        response = 'error: invalid request data'
        @ceEngine.history.send [ref, JSON.stringify response]
      else
        if typeof startSequence == 'number'
          if startSequence > @currentSequence 
            response = 'error: start ID must be the next ID or earlier'
            @ceEngine.history.send [ref, JSON.stringify response]
          else
            response = @history.slice startSequence
            @ceEngine.history.send [ref, JSON.stringify response]
        else
          response = 'error: invalid start ID'
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
