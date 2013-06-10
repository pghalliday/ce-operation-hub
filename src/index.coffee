Server = require './Server'
nconf = require 'nconf'

# load configuration
nconf.argv()
config = nconf.get 'config'
if config
  nconf.file
    file: config
bindAddress = nconf.get 'bind-address'

server = new Server
  bindAddress: bindAddress

server.start (error) ->
  if error
    console.log error
  else
    console.log 'ce-operation-hub started on address ' + bindAddress
