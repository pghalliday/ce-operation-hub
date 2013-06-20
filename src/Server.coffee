zmq = require 'zmq'

module.exports = class Server
  constructor: (@options) ->
    @currentId = 0
    @ceFrontEnd = zmq.socket 'xrep'
    @ceFrontEnd.setsockopt 'linger', 0
    @ceEngine = 
      stream: zmq.socket 'pub'
      result: zmq.socket 'pull'
    @ceEngine.stream.setsockopt 'linger', 0
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
        id = @currentId++
        operation.id = id
        replyHandler = (message) =>
          operation = JSON.parse message
          if operation.id == id
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



  stop: (callback) =>
    @ceFrontEnd.close()
    @ceEngine.stream.close()
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
            @ceEngine.result.bind 'tcp://*:' + @options['ce-engine'].result, (error) =>
              if error
                @ceFrontEnd.close()
                @ceEngine.stream.close()
                callback error
              else
                callback()
