rewire = require 'rewire'
Address = require('./address.js').Address;

# set haraka globals
constants = require './constants.js'
global.DENY = constants.deny
global.OK = constants.ok

plugin =
connection =
params =

describe "register", ->

  beforeEach ->
    plugin = rewire("./aliases_mysql.js");
    # implement methods from haraka plugins.js
    plugin.inherits = jasmine.createSpy('inherits')
    plugin.register_hook = jasmine.createSpy('register_hook')

  it 'should inherit plugin queue/discard', () ->
    plugin.register();
    expect(plugin.inherits).toHaveBeenCalledWith('queue/discard');

  it 'should register hook for rcpt with aliases_mysql', () ->
    plugin.register();
    expect(plugin.register_hook).toHaveBeenCalledWith('rcpt', 'aliases_mysql');


describe "aliases mysql", ->
  next =

  beforeEach ->
    plugin = rewire "./aliases_mysql.js"
    next = jasmine.createSpy('next')
    params = [ new Address 'test@test.dev', {} ]
    connection =
      transaction:
        notes:
          local_sender: true
      logdebug: () -> jasmine.createSpy('logdebug')
      loginfo: () -> jasmine.createSpy('loginfo')

  it "should call 'getAliasByEmail' with correct parameters", ->
    spyOn(plugin, "getAliasByEmail").andCallFake ->

    plugin.aliases_mysql(next, connection, params);
    expect(plugin.getAliasByEmail).toHaveBeenCalledWith(connection, params[0].address(), jasmine.any(Function));

  it "should not call 'getAliasByEmail' but call next function when no local_sender flag", ->
    spyOn(plugin, "getAliasByEmail").andCallFake ->

    testConnection = connection
    testConnection.transaction.notes.local_sender = false

    plugin.aliases_mysql(next, connection, params);
    expect(next).toHaveBeenCalled();
    expect(plugin.getAliasByEmail.wasCalled).toBeFalsy();

  it "should call next function when 'getAliasByEmail' fails", ->
    spyOn(plugin, "getAliasByEmail").andCallFake (connection, rcpt, callback) -> callback new Error 'failed'

    plugin.aliases_mysql(next, connection, params);
    expect(next).toHaveBeenCalledWith();

  it "should call 'drop' and next with correct parameters when alias is set to drop", ->
    spyOn(plugin, "getAliasByEmail").andCallFake (connection, rcpt, callback) -> callback null, {action: "drop"}
    spyOn(plugin, 'drop').andCallFake ->

    plugin.aliases_mysql(next, connection, params);
    expect(plugin.drop).toHaveBeenCalledWith(connection, params[0].address());
    expect(next).toHaveBeenCalledWith(DENY);

  it "should call 'alias' and next with correct parameters when alias is set to alias", ->
    spyOn(plugin, "getAliasByEmail").andCallFake (connection, rcpt, callback) -> callback null, {action: "alias"}
    spyOn(plugin, 'alias').andCallFake ->

    plugin.aliases_mysql(next, connection, params);
    expect(plugin.alias).toHaveBeenCalledWith(connection, params[0].address(), {action: "alias"});
    expect(next).toHaveBeenCalledWith(OK);

  it "should call next when alias action is unknown", ->
    spyOn(plugin, "getAliasByEmail").andCallFake (connection, rcpt, callback) -> callback null, {action: "unknown"}

    plugin.aliases_mysql(next, connection, params);
    expect(next).toHaveBeenCalledWith();


describe "get alias by email", ->

  beforeEach ->
    plugin = rewire "./aliases_mysql.js"
    plugin.config =
      get: jasmine.createSpy('get').andCallFake () ->
        main:
          host: 'localhost',
          port: 3306,
          char_set: 'UTF8_GENERAL_CI',
          ssl: false,
          alias_query: "SELECT * FROM aliases WHERE email = '%u'"
    connection =
      transaction:
        notes:
          local_sender: true
      logdebug: () -> jasmine.createSpy('logdebug')
      loginfo: () -> jasmine.createSpy('loginfo')

  it "should load config", ->
    spyOn(plugin, "connectMysql").andCallFake () ->

    plugin.getAliasByEmail connection, 'test@test.dev', () ->
    expect(plugin.config.get).toHaveBeenCalled();

  it "should set default config if config file failed to load", ->
    plugin.config.get = jasmine.createSpy('get').andCallFake () ->
    spyOn(plugin, "connectMysql").andCallFake () ->

    plugin.getAliasByEmail connection, 'test@test.dev', () ->
    expect(plugin.connectMysql).toHaveBeenCalledWith(jasmine.any(Object), plugin.__get__('mysqlDefault').main, jasmine.any(Function));

  it "should set default alias_query when alias_query is not configured", ->
    configDefault =  plugin.__get__('mysqlDefault')
    configWithoutQuery =  plugin.__get__('mysqlDefault')
    delete configWithoutQuery.main.alias_query

    plugin.config.get = jasmine.createSpy('get').andCallFake () -> configWithoutQuery
    spyOn(plugin, "connectMysql").andCallFake () ->

    plugin.getAliasByEmail connection, 'test@test.dev', () ->
    expect(plugin.connectMysql).toHaveBeenCalledWith(jasmine.any(Object), configDefault.main, jasmine.any(Function));

  it "should call connectMysql with the correct parameters", ->
    spyOn(plugin, "connectMysql").andCallFake () ->

    plugin.getAliasByEmail connection, 'test@test.dev', () ->
    expect(plugin.connectMysql).toHaveBeenCalledWith(connection, plugin.config.get().main, jasmine.any(Function));

  it "should call callback with error on connection error", ->
    callbackSpy = jasmine.createSpy().andCallFake () ->

    spyOn(plugin, "connectMysql").andCallFake (connection, config, cb) -> return cb new Error 'fail callback'

    plugin.getAliasByEmail connection, 'test@test.dev', callbackSpy
    expect(callbackSpy).toHaveBeenCalledWith(new Error 'fail callback')

  it "should call mysqlConnection.query with correct email", ->
    querySpy = jasmine.createSpy('queryCallback').andCallFake (query, params, cb) ->

    spyOn(plugin, "connectMysql").andCallFake (connection, config, cb) -> cb null, {
      query: querySpy
    }

    plugin.getAliasByEmail connection, 'test@test.dev', () ->
    expect(querySpy).toHaveBeenCalledWith("SELECT * FROM aliases WHERE email = 'test@test.dev'", [], jasmine.any(Function))

    plugin.getAliasByEmail connection, 'dev@sample.com', () ->
    expect(querySpy).toHaveBeenCalledWith("SELECT * FROM aliases WHERE email = 'dev@sample.com'", [], jasmine.any(Function))

  it "should call callback with error on alias query error", ->
    querySpy = jasmine.createSpy('queryCallback').andCallFake (query, params, cb) -> return cb new Error 'fail callback'
    callbackSpy = jasmine.createSpy('callback').andCallFake () ->

    spyOn(plugin, "connectMysql").andCallFake (connection, config, cb) -> cb null, {
      query: querySpy
    }

    plugin.getAliasByEmail connection, 'test@test.dev', callbackSpy
    expect(callbackSpy).toHaveBeenCalledWith(new Error 'fail callback')

  it "should call callback with correct results", ->
    querySpy = jasmine.createSpy('queryCallback').andCallFake (query, params, cb) -> return cb(null, [{address: "test@test.dev", action: "drop"}])
    callbackSpy = jasmine.createSpy('callback').andCallFake () ->

    spyOn(plugin, "connectMysql").andCallFake (connection, config, cb) -> cb null, {
      query: querySpy
    }

    plugin.getAliasByEmail connection, 'test@test.dev', callbackSpy
    expect(callbackSpy).toHaveBeenCalledWith(null, {address: "test@test.dev", action: "drop"})

  it "should call callback with error when alias address does not match given address", ->
    querySpy = jasmine.createSpy('queryCallback').andCallFake (query, params, cb) -> return cb(null, [{address: "test2@test.dev", action: "drop"}])
    callbackSpy = jasmine.createSpy('callback').andCallFake () ->

    spyOn(plugin, "connectMysql").andCallFake (connection, config, cb) -> cb null, {
      query: querySpy
    }

    plugin.getAliasByEmail connection, 'test@test.dev', callbackSpy
    expect(callbackSpy).toHaveBeenCalledWith(new Error("No alias entry for test@test.dev"))


describe "drop", ->

  beforeEach ->
    plugin = rewire "./aliases_mysql.js"
    connection =
      transaction:
        notes:
          local_sender: true
          discard: false
      logdebug: () -> jasmine.createSpy('logdebug')
      loginfo: () -> jasmine.createSpy('loginfo')

  it "should set discard flag", ->
    plugin.drop connection, 'test@test.dev'
    expect(connection.transaction.notes.discard).toBeTruthy();


describe "alias", ->

  beforeEach ->
    plugin = rewire "./aliases_mysql.js"
    connection =
      transaction:
        notes:
          local_sender: true
          discard: false
        rcpt_to: [new Address "test@test.dev"]
      logdebug: () -> jasmine.createSpy('logdebug')
      loginfo: () -> jasmine.createSpy('loginfo')

  it "should return false when invalid forwarder object", ->
    expect(plugin.alias connection, 'test@test.dev', null).toBe(false);
    expect(plugin.alias connection, 'test@test.dev', {}).toBe(false);
    expect(plugin.alias connection, 'test@test.dev', {aliases: []}).toBe(false);
    expect(plugin.alias connection, 'test@test.dev', {aliases: ""}).toBe(false);

  it "should set add alias targets into transaction.rcpt_to", ->
    plugin.alias connection, 'test@test.dev', {aliases: "test2@test.dev"}
    expect(connection.transaction.rcpt_to).toEqual([new Address('<test2@test.dev>')]);

  it "should set add alias targets into transaction.rcpt_to", ->
    plugin.alias connection, 'test@test.dev', {aliases: "test2@test.dev|test3@test.dev"}
    expect(connection.transaction.rcpt_to).toEqual([new Address('<test2@test.dev>'), new Address('<test3@test.dev>')]);

  it "should set relaying flag", ->
    plugin.alias connection, 'test@test.dev', {aliases: "test2@test.dev|test3@test.dev"}
    expect(connection.relaying).toBeTruthy();


describe "connectMysql", ->
  config =

  beforeEach ->
    plugin = rewire "./aliases_mysql.js"
    plugin.__set__ 'mysql',
      createConnection: jasmine.createSpy('createConnection').andCallFake () ->
        connect: jasmine.createSpy('connect').andCallFake (callback) -> return callback null, true
        on: jasmine.createSpy('on').andCallFake () ->
    config =
      host: 'localhost',
      port: 3306,
      char_set: 'UTF8_GENERAL_CI',
      ssl: false,
      alias_query: "SELECT * FROM aliases WHERE email = '%u'"
    connection =
      transaction:
        notes:
          local_sender: true
          discard: false
        rcpt_to: [new Address "test@test.dev"]
      logdebug: () -> jasmine.createSpy('logdebug')
      loginfo: () -> jasmine.createSpy('loginfo')

  it "should return existing mysql connection in callback", (done) ->
    plugin.__set__ 'mysqlConnection', {"one": "two"}

    plugin.connectMysql connection, config, (err, connection) ->
      expect(connection).toEqual({"one": "two"})
      done()

  it "should call mysql.createConnection function", (done) ->
    plugin.connectMysql connection, config, (err, connection) ->
      expect(plugin.__get__('mysql').createConnection).toHaveBeenCalled()
      done()

  it "should call connection.connect function", (done) ->
    connectionCaller = jasmine.createSpy('connect').andCallFake (callback) -> return callback null, true

    plugin.__set__ 'mysql',
      createConnection: jasmine.createSpy('createConnection').andCallFake () ->
        connect: connectionCaller
        on: jasmine.createSpy('on').andCallFake () ->

    plugin.connectMysql connection, config, (err, connection) ->
      expect(connectionCaller).toHaveBeenCalled()
      done()

  it "should set on error callback on connection", (done) ->
    onCaller = jasmine.createSpy('connect').andCallFake () ->

    plugin.__set__ 'mysql',
      createConnection: jasmine.createSpy('createConnection').andCallFake () ->
        connect: jasmine.createSpy('connect').andCallFake (callback) -> return callback null, true
        on: onCaller

    plugin.connectMysql connection, config, (err, connection) ->
      expect(onCaller).toHaveBeenCalledWith('error', jasmine.any(Function))
      done()

  it "should fail when connection.connect fails", (done) ->
    connectionCaller = jasmine.createSpy('connect').andCallFake (callback) -> return callback new Error 'error'

    plugin.__set__ 'mysql',
      createConnection: jasmine.createSpy('createConnection').andCallFake () ->
        connect: connectionCaller
        on: jasmine.createSpy('on').andCallFake () ->

    plugin.connectMysql connection, config, (err, connection) ->
      expect(err).toEqual(new Error 'errors')
      done()

  it "should set connection property", (done) ->
    plugin.connectMysql connection, config, (err, connection) ->
      expect(plugin.__get__ "mysqlConnection").toBeTruthy()
      done()

  it "should run connect only one time", (done) ->
    connectionCaller = jasmine.createSpy('connect').andCallFake (callback) -> return callback null, true

    plugin.__set__ 'mysql',
      createConnection: jasmine.createSpy('createConnection').andCallFake () ->
        connect: connectionCaller
        on: jasmine.createSpy('on').andCallFake () ->

    plugin.connectMysql connection, config, (err, connection) ->
      plugin.connectMysql connection, config, (err, connection) ->
        plugin.connectMysql connection, config, (err, connection) ->
          expect(connectionCaller.callCount).toBe(1)
          done()

  it "should call connection.end and resets connection after a mysql connection error occurred", (done) ->
    endCaller = jasmine.createSpy('end').andCallFake () ->

    plugin.__set__ 'mysql',
      createConnection: jasmine.createSpy('createConnection').andCallFake () ->
        connect: jasmine.createSpy('connect').andCallFake (callback) -> return callback null, true
        end: endCaller
        on: jasmine.createSpy('on').andCallFake (event, callback) ->
          this.onError = callback if(event == 'error')
        onError: () ->

    plugin.connectMysql connection, config, (err, connection) ->
      connection.onError ('some error')
      expect(endCaller).toHaveBeenCalled()
      expect(plugin.__get__ "mysqlConnection").toBeFalsy()
      done()
