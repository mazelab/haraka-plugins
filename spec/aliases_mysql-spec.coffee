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
          query: 'SELECT * FROM aliases WHERE email = "%u"'
    connection =
      transaction:
        notes:
          local_sender: true
      server:
        notes:
          mysql_provider:
            query: jasmine.createSpy('mysql_provider.query').andCallFake (query, callback) ->
              callback null, [{address: "test@test.dev", action: "alias", aliases: "test2@test.dev|test3@test.dev"}]
      logdebug: () -> jasmine.createSpy('logdebug')
      loginfo: () -> jasmine.createSpy('loginfo')

  it "should fail when mysql provider is not initialized", (done) ->
    delete connection.server.notes.mysql_provider

    plugin.getAliasByEmail connection, 'test@test.dev', (err) ->
      expect(err).toEqual(new Error 'mysql provider seems mot initialized')
      done()

  it "should load config", (done) ->
    plugin.getAliasByEmail connection, 'test@test.dev', () ->
      expect(plugin.config.get).toHaveBeenCalledWith('aliases_mysql.ini', 'ini');
      done()

  it "should use configured query", (done) ->
    expectedQuery = 'SELECT * FROM aliases WHERE email = "test@test.dev"';

    plugin.getAliasByEmail connection, 'test@test.dev', () ->
      expect(connection.server.notes.mysql_provider.query).toHaveBeenCalledWith(expectedQuery ,jasmine.any(Function));
      done()

  it "should set default query when query is not configured", (done) ->
    plugin.config.get = jasmine.createSpy('get').andCallFake () -> return {main:{}}

    expectedQuery = 'SELECT address, action, aliases FROM forwarder WHERE address = "test@test.dev"';

    plugin.getAliasByEmail connection, 'test@test.dev', () ->
      expect(connection.server.notes.mysql_provider.query).toHaveBeenCalledWith(expectedQuery ,jasmine.any(Function));
      done()

  it "should fail on query error", (done) ->
    error = new Error 'fail callback'

    connection.server.notes.mysql_provider.query = jasmine.createSpy('mysql_provider')
    .andCallFake (query, callback) -> return callback error

    plugin.getAliasByEmail connection, 'test@test.dev', (err) ->
      expect(err).toBe(error)
      done()

  it "should fail when query result is empty", (done) ->
    connection.server.notes.mysql_provider.query = jasmine.createSpy('mysql_provider')
    .andCallFake (query, callback) -> return callback null, []

    plugin.getAliasByEmail connection, 'test@test.dev', (err) ->
      expect(err).toBeTruthy()
      done()

  it "should fail when query result has no address", (done) ->
    connection.server.notes.mysql_provider.query = jasmine.createSpy('mysql_provider')
    .andCallFake (query, callback) -> return callback null, [{"address": ""}]

    plugin.getAliasByEmail connection, 'test@test.dev', (err) ->
      expect(err).toBeTruthy()
      done()

  it "should fail when query result has a different address", (done) ->
    connection.server.notes.mysql_provider.query = jasmine.createSpy('mysql_provider')
    .andCallFake (query, callback) -> return callback null, [{"address": "test2@test.dev"}]

    plugin.getAliasByEmail connection, 'test@test.dev', (err) ->
      expect(err).toBeTruthy()
      done()

  it "should call callback with correct results", (done) ->
    plugin.getAliasByEmail connection, 'test@test.dev', (err, result) ->
      expect(result).toEqual({address: "test@test.dev", action: "alias", aliases: "test2@test.dev|test3@test.dev"})
      done()


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
