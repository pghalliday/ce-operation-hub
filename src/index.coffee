Server = require './Server'
nconf = require 'nconf'

# load configuration
nconf.argv()
config = nconf.get 'config'
if config
  nconf.file
    file: config
ceFrontEndXReply = nconf.get 'ce-front-end-xreply'
ceEnginePublisher = nconf.get 'ce-engine-publisher'
ceEnginePull = nconf.get 'ce-engine-pull'

server = new Server
  ceFrontEndXReply: ceFrontEndXReply
  ceEnginePublisher: ceEnginePublisher
  ceEnginePull: ceEnginePull

server.start (error) ->
  if error
    console.log error
  else
    console.log 'ce-operation-hub started'
    console.log '\tce-front-end-xreply: ' + ceFrontEndXReply
    console.log '\tce-engine-publisher: ' + ceEnginePublisher
    console.log '\tce-engine-pull: ' + ceEnginePull