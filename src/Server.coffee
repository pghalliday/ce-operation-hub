http = require 'http'
zmq = require 'zmq'

module.exports = class Server
  constructor: (@options) ->
    @ceFrontEnd = zmq.socket 'xrep'
    @ceFrontEnd.on 'message', =>
      args = Array.apply null, arguments
      order = JSON.parse args[2]
      order.id = '654321'
      args[2] = JSON.stringify order
      @ceFrontEnd.send args

  stop: (callback) =>
    @ceFrontEnd.close()
    callback()

  start: (callback) =>
    @ceFrontEnd.bind @options.bindAddress, callback
