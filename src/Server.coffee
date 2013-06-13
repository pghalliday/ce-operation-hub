zmq = require 'zmq'

module.exports = class Server
  constructor: (@options) ->
    @currentId = 0
    @ceFrontEndXReply = zmq.socket 'xrep'
    @ceFrontEndXReply.setsockopt 'linger', 0
    @ceEnginePublisher = zmq.socket 'pub'
    @ceEnginePublisher.setsockopt 'linger', 0
    @ceEnginePull = zmq.socket 'pull'
    @ceEnginePull.setsockopt 'linger', 0
    @ceFrontEndXReply.on 'message', =>
      args = Array.apply null, arguments
      order = JSON.parse args[2]
      id = @currentId++
      order.id = id
      replyHandler = (message) =>
        order = JSON.parse message
        if order.id == id
          @ceEnginePull.removeListener 'message', replyHandler
          args[2] = JSON.stringify order
          @ceFrontEndXReply.send args
      @ceEnginePull.on 'message', replyHandler
      @ceEnginePublisher.send JSON.stringify order

  stop: (callback) =>
    @ceFrontEndXReply.close()
    @ceEnginePublisher.close()
    @ceEnginePull.close()
    callback()

  start: (callback) =>
    @ceFrontEndXReply.bind @options.ceFrontEndXReply, (error) =>
      if error
        callback error
      else
        @ceEnginePublisher.bind @options.ceEnginePublisher, (error) =>
          if error
            @ceFrontEndXReply.close()
            callback error
          else
            @ceEnginePull.bind @options.ceEnginePull, (error) =>
              if error
                @ceFrontEndXReply.close()
                @ceEnginePublisher.close()
                callback error
              else
                callback()
