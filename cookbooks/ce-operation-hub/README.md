cookbook-ce-operation-hub
=========================

Chef cookbook to install and start a ce-operation-hub instance

## Depends

- nodejs
- git
- zeromq (https://github.com/pghalliday/cookbook-zeromq.git)

## Attributes

Attributes are specified under the `ce_operation_hub` keyspace.

- `node[:ce_operation_hub][:repository]` - the Git repository to install `ce-operation-hub` from (defaults to "https://github.com/pghalliday/ce-operation-hub.git")
- `node[:ce_operation_hub][:destination]` - the directory to install `ce-operation-hub` to (defaults to "/opt/ce-operation-hub")
- `node[:ce_operation_hub][:user]` - the user to install and start `ce-operation-hub` as (defaults to "ce-operation-hub")
- `node[:ce_operation_hub][:ce_front_end][:submit]` - the port to bind the `ce-operation-hub` to recieve and reply to operations from `ce-front-end` instances (defaults to "4000")
- `node[:ce_operation_hub][:ce_engine][:stream]` - the port to bind the `ce-operation-hub` to publish operations to `ce-engine` instances (defaults to "4001")
- `node[:ce_operation_hub][:ce_engine][:history]` - the port to bind the `ce-operation-hub` to reply to requests for the operation history to `ce-engine` instances (defaults to "4002")
- `node[:ce_operation_hub][:ce_engine][:result]` - the port to bind the `ce-operation-hub` to pull operation results from `ce-engine` instances (defaults to "4003")
- `node[:ce_operation_hub][:ce_engine][:timeout]` - the number of milliseconds the `ce-operation-hub` will wait for a result from a `ce-engine` instance (defaults to "2000")

## Recipes

### default

- Installs `ce-operation-hub`
- Runs npm install to get dependencies
- Runs npm start to start the `ce-operation-hub`

## License
Copyright &copy; 2013 Peter Halliday  
Licensed under the MIT license.
