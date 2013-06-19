ce-operation-hub
================

[![Build Status](https://travis-ci.org/pghalliday/ce-operation-hub.png?branch=master)](https://travis-ci.org/pghalliday/ce-operation-hub)
[![Dependency Status](https://gemnasium.com/pghalliday/ce-operation-hub.png)](https://gemnasium.com/pghalliday/ce-operation-hub)

Nexus for receiving currency exchange operations from ce-front-end instances, assigning sequence IDs, logging and broadcasting them to ce-engine instances.

## Configuration

configuration should be placed in a file called `config.json` in the root of the project

```javascript
{
  // Listens for operations from `ce-front-end` instances
  "ce-front-end": {
    // Port for 0MQ `xrep` socket
    "submit": 7000
  },
  // Streams operations to and listens for operation results from `ce-engine` instances
  "ce-engine": {
    // Port for 0MQ `pub` socket
    "stream": 7001,
    // Port for 0MQ `pull` socket
    "result": 7002
  }
}
```

## Starting and stopping the server

Forever is used to keep the server running as a daemon and can be called through npm as follows

```
$ npm start
$ npm stop
```

Output will be logged to the following files

- `~/.forever/forever.log` Forever output
- `./out.log` stdout
- `./err.log` stderr

## API

Operations should be submitted in the following format

```javascript
{
  "account": "[account]",
  "[operation]": {
    ...
  }
}
```

The result will be returned in the following format

```javascript
{
  "account": "[account]",
  "id": "1234567890",
  "result": "success"
  "[operation]": {
    ...
  }
}
```

Note that the `id` is assigned sequentially by the `ce-operation-hub` and the `result` is assigned by a `ce-engine` instance

## Roadmap

- Should maintain a history of operations
- Should allow a `ce-engine` instance to catch up with operations from the history that it has not yet applied (after connection failure or reboot, for instance)
- Should persist the history of operations (external database?)

## Contributing
In lieu of a formal styleguide, take care to maintain the existing coding style. Add unit tests for any new or changed functionality. Test your code using: 

```
$ npm test
```

### Using Vagrant
To use the Vagrantfile you will also need to install the following vagrant plugins

```
$ vagrant plugin install vagrant-omnibus
$ vagrant plugin install vagrant-berkshelf
```

The cookbook used by vagrant is located in a git submodule so you will have to intialise that after cloning

```
$ git submodule init
$ git submodule update
```

## License
Copyright &copy; 2013 Peter Halliday  
Licensed under the MIT license.
