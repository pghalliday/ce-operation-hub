ce-operation-hub
================

[![Build Status](https://travis-ci.org/pghalliday/ce-operation-hub.png?branch=master)](https://travis-ci.org/pghalliday/ce-operation-hub)
[![Dependency Status](https://gemnasium.com/pghalliday/ce-operation-hub.png)](https://gemnasium.com/pghalliday/ce-operation-hub)

Nexus for receiving currency exchange operations from ce-front-end instances, assigning sequence IDs, logging and broadcasting them to ce-engine instances.

## Configuration

configuration should be placed in a file called `config.json` in the root of the project

```javascript
{
  // Listens for operations submitted by `ce-front-end` instances
  "ce-front-end": {
    // Port for 0MQ `xrep` socket
    "submit": 7000
  },
  // Streams and provides a history of operations to and listens
  // for operation results from `ce-engine` instances
  "ce-engine": {
    // Port for 0MQ `pub` socket
    "stream": 7001,
    // Port for 0MQ 'xrep' socket
    "history": 7002,
    // Port for 0MQ `pull` socket
    "result": 7003,
    // The number of milliseconds to wait for results from the `ce-engine` instances
    "timeout": 2000
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

### Submit an operation

`ce-front-end` instances should connect a 0MQ `xreq` socket to the configured `ce-front-end/submit` port and submit operations over that

Request:

```javascript
{
  "reference": "550e8400-e29b-41d4-a716-446655440000",
  "account": "[account]",
  "[operation]": {
    ...
  }
}
```

The `reference` field can be used by the `ce-front-end` instance to match the result to the the original HTTP request and as such will be returned untouched by any of the downstream components

Reply:

```javascript
{
  "reference": "550e8400-e29b-41d4-a716-446655440000",
  "account": "[account]",
  "sequence": 1234567890,
  "timestamp": 1371737390976,
  "result": "[result]",
  "[operation]": {
    ...
  }
}
```

Possible results include

- `[ce-engine result]` - the result pushed by a `ce-engine` instance
- `pending` - the operation was not processed by a `ce-engine` instance within the configured timeout period. In this case the operation may still be applied at some point and will have been added to the operation history. A `ce-front-end` instance could only know if the operation is eventually applied by watching for deltas from a `ce-delta-hub`

If the request data cannot be parsed by the `ce-operation-hub` the following reply will be sent:

```javascript
{
  "result": "error: invalid request data",
}
```

### Handling the stream of operations

`ce-engine` instances should connect a 0MQ `sub` socket to the configured `ce-engine/stream` port and a 0MQ `push` socket to the configured `ce-engine/result` port

Submitted operations will be assigned a `sequence` number and timestamp as a unix time in milliseconds since epoch and streamed to the `ce-engine` instances in the following format

```javascript
{
  "reference": "550e8400-e29b-41d4-a716-446655440000",
  "account": "[account]",
  "sequence": 1234567890,
  "timestamp": 1371737390976,
  "[operation]": {
    ...
  }
}
```

The `ce-engine` instances should then push the result in the following format

```javascript
{
  "reference": "550e8400-e29b-41d4-a716-446655440000",
  "account": "[account]",
  "sequence": 1234567890,
  "timestamp": 1371737390976,
  "result": "[result]",
  "[operation]": {
    ...
  }
}
```

### Get the history of operations

`ce-engine` instances should connect a 0MQ `xreq` socket to the configured `ce-engine/history` port

When requesting the history of operations, a `ce-engine` instance should supply the next operation ID it is expecting and operations will be returned from that ID onwards

Request:

```javacscript
1234567890
```

Reply:

```javacscript
[{
  "reference": "550e8400-e29b-41d4-a716-446655440000",
  "account": "[account]",
  "sequence": 1234567890,
  "timestamp": 1371737390976,
  "[operation]": {
    ...
  }
}, {
  "reference": "550e8401-e29b-41d4-a716-446655440000",
  "account": "[account]",
  "sequence": 1234567891,
  "timestamp": 1371737390980,
  "[operation]": {
    ...
  }
}, {
  "reference": "550e8402-e29b-41d4-a716-446655440000",
  "account": "[account]",
  "sequence": 1234567892,
  "timestamp": 1371737390998,
  "[operation]": {
    ...
  }
}, {
  "reference": "550e8403-e29b-41d4-a716-446655440000",
  "account": "[account]",
  "sequence": 1234567893,
  "timestamp": 1371737391005,
  "[operation]": {
    ...
  }
}]
```

Note that the `ce-engine` instance should push the results back to the `ce-operation-hub` after processing the operations and not assume that another `ce-engine` instance has already done so.

## Roadmap

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
