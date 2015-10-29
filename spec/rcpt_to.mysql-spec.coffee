rewire = require 'rewire'
Address = require('./address.js').Address;

# set haraka globals
constants = require './constants.js'
global.OK = constants.ok

plugin =
connection =
params =

describe "register", ->

  beforeEach ->
    plugin = rewire("./rcpt_to.mysql.js");
    plugin.register_hook = jasmine.createSpy('register_hook')
    plugin.load_cfg_ini = jasmine.createSpy('load_cfg_ini')

  it 'should register hook for rcpt with rcpt_mysql', ->
    plugin.register();
    expect(plugin.register_hook).toHaveBeenCalledWith('rcpt', 'rcpt_mysql');

  it "should call load cfg ini", ->
    plugin.register();
    expect(plugin.load_cfg_ini).toHaveBeenCalled();


describe "load cfg ini", ->

  beforeEach ->
    plugin = rewire "./rcpt_to.mysql.js"
    plugin.config =
      get: jasmine.createSpy('get').andCallFake () ->
        main:
          query: 'SELECT * FROM users WHERE address = "%u"'

  it "should call plugin.config.get", ->
    plugin.load_cfg_ini()
    expect(plugin.config.get).toHaveBeenCalledWith('rcpt_to.mysql.ini', jasmine.any(Function))

  it "should set cfg property", ->
    config =
      main:
        query: 'SELECT * FROM users WHERE address = "%u"'

    plugin.config.get.andCallFake () -> config

    plugin.load_cfg_ini()
    expect(plugin.cfg).toBe(config)


describe "rcpt mysql", ->
  next =

  beforeEach ->
    plugin = rewire "./rcpt_to.mysql.js"
    plugin.in_mysql = jasmine.createSpy('in_mysql').andCallFake (connection, address, callback) -> callback null, true
    next = jasmine.createSpy('next')
    params = [ new Address('test@test.dev'), {} ]
    connection =
      transaction:
        notes: {}
        results:
          add: jasmine.createSpy('txn.results.add')
      logdebug: () -> jasmine.createSpy('logdebug')
      loginfo: () -> jasmine.createSpy('loginfo')
      logwarn: () -> jasmine.createSpy('logwarn')

  it "should call 'in_mysql' with correct parameters", ->
    plugin.rcpt_mysql next, connection, params
    expect(plugin.in_mysql).toHaveBeenCalledWith(connection, params[0], jasmine.any(Function))

  it "should not call next when connection.transaction or params is missing", ->
    plugin.rcpt_mysql next, connection, []
    expect(next.callCount).toBe(0)

    connection.transaction = null

    plugin.rcpt_mysql next, connection, params
    expect(next.callCount).toBe(0)

  it "should call next(OK) when connection.relaying and local_sender", ->
    connection.relaying = true
    connection.transaction.notes.local_sender = true

    plugin.rcpt_mysql next, connection, params
    expect(next).toHaveBeenCalledWith(OK)

  it "should not call in_mysql when connection.relaying and local_sender", ->
    connection.relaying = true
    connection.transaction.notes.local_sender = true

    plugin.rcpt_mysql next, connection, params
    expect(plugin.in_mysql.callCount).toBe(0)

  it "should call next when when either connection.relaying or local_sender", ->
    plugin.in_mysql.andCallFake (connection, address, callback) -> callback null, null

    connection.relaying = true
    connection.transaction.notes.local_sender = false

    plugin.rcpt_mysql next, connection, params
    expect(next).toHaveBeenCalledWith()

    connection.relaying = false
    connection.transaction.notes.local_sender = true

    plugin.rcpt_mysql next, connection, params
    expect(next).toHaveBeenCalledWith()

  it "should call next when 'in_mysql' fails", ->
    plugin.in_mysql.andCallFake (connection, address, callback) -> callback new Error 'totally failed'

    plugin.rcpt_mysql(next, connection, params);
    expect(next).toHaveBeenCalledWith();

  it "should call next(OK) when in_mysql result is true", ->
    plugin.in_mysql.andCallFake (connection, address, callback) -> callback null, true

    plugin.rcpt_mysql next, connection, params
    expect(next).toHaveBeenCalledWith(OK)

  it "should call next when in_mysql result is null", ->
    plugin.in_mysql.andCallFake (connection, address, callback) -> callback null, null

    plugin.rcpt_mysql next, connection, params
    expect(next).toHaveBeenCalledWith()


describe "in mysql", ->

  beforeEach ->
    plugin = rewire "./rcpt_to.mysql.js"
    plugin.cfg =
      main:
        query: 'SELECT * FROM aliases WHERE address = "%u"'
    connection =
      transaction:
        notes: {}
        results:
          add: jasmine.createSpy('txn.results.add')
      server:
        notes:
          mysql_provider:
            query: jasmine.createSpy('mysql_provider.query').andCallFake (query, callback) ->
              callback null, [{address: "test@test.dev", action: "alias", aliases: "test2@test.dev|test3@test.dev"}]
      logdebug: () -> jasmine.createSpy('logdebug')
      loginfo: () -> jasmine.createSpy('loginfo')


  it "should fail when mysql provider is not initialized", (done) ->
    delete connection.server.notes.mysql_provider

    plugin.in_mysql connection, new Address('test@test.dev'), (err) ->
      expect(err).toEqual(new Error 'mysql provider seems mot initialized')
      done()

  it "should use configured query", (done) ->
    expectedQuery = 'SELECT * FROM aliases WHERE address ='

    plugin.cfg.main.query = expectedQuery

    plugin.in_mysql connection, new Address('test@test.dev'), () ->
      expect(connection.server.notes.mysql_provider.query).toHaveBeenCalledWith(expectedQuery ,jasmine.any(Function));
      done()

  it "should replace domain, host and email in query string", (done) ->
    expectedQuery = 'domain: "test.dev", user: "test", email: "test@test.dev"';
    plugin.cfg.main.query = 'domain: "%d", user: "%n", email: "%u"'

    plugin.in_mysql connection, new Address('test@test.dev'), () ->
      expect(connection.server.notes.mysql_provider.query).toHaveBeenCalledWith(expectedQuery ,jasmine.any(Function));
      done()

  it "should fail when query is not configured", (done) ->
    plugin.cfg.main = {}

    plugin.in_mysql connection, new Address('test@test.dev'), (err) ->
      expect(err).toBeTruthy();
      done()

  it "should fail on query error", (done) ->
    error = new Error 'fail callback'
    connection.server.notes.mysql_provider.query.andCallFake (query, callback) -> return callback error

    plugin.in_mysql connection, new Address('test@test.dev'), (err) ->
      expect(err).toBe(error)
      done()

  it "should call callback with correct results", (done) ->
    plugin.in_mysql connection, new Address('test@test.dev'), (err, result) ->
      expect(result).toEqual(true)
      done()

  it "should call callback with null when empty result", (done) ->
    connection.server.notes.mysql_provider.query.andCallFake (query, callback) -> return callback null, []

    plugin.in_mysql connection, new Address('test@test.dev'), (err, result) ->
      expect(result).toEqual(null)
      done()
