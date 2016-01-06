rewire = require 'rewire'
Address = require('./address.js').Address;
DSN = require './dsn'

plugin =
params =
connection =
next =

describe "register", ->

  beforeEach ->
    plugin = rewire("./quota_mysql.js");
    plugin.register_hook = jasmine.createSpy('register_hook')

  it 'should register hook for rcpt with quota_mysql', () ->
    plugin.register();
    expect(plugin.register_hook).toHaveBeenCalledWith('rcpt_ok', 'quota_mysql');


describe "is numeric", ->

  beforeEach ->
    plugin = rewire("./quota_mysql.js");

  it "should return true", ->
    expect(plugin.isNumeric(-1)).toBeTruthy()
    expect(plugin.isNumeric(-1.5)).toBeTruthy()
    expect(plugin.isNumeric(100)).toBeTruthy()
    expect(plugin.isNumeric('200')).toBeTruthy()
    expect(plugin.isNumeric('0x89f')).toBeTruthy()
    expect(plugin.isNumeric(.1223)).toBeTruthy()

  it "should return false", ->
    expect(plugin.isNumeric(null)).toBeFalsy()
    expect(plugin.isNumeric('')).toBeFalsy()
    expect(plugin.isNumeric('ten')).toBeFalsy()
    expect(plugin.isNumeric('99,999')).toBeFalsy()
    expect(plugin.isNumeric('1.2.3')).toBeFalsy()

describe "calc bytes in megabytes", ->

  beforeEach ->
    plugin = rewire("./quota_mysql.js");

  it "should return correct values", ->
    expect(plugin.calcBytesInMegaBytes(2097152)).toEqual('2.0')
    expect(plugin.calcBytesInMegaBytes(2306867.2)).toEqual('2.2')

  it "should return comparable value", ->
    expect(plugin.calcBytesInMegaBytes(2097152) > 1).toBeTruthy()
    expect(plugin.calcBytesInMegaBytes(2097152) > 1.0).toBeTruthy()
    expect(plugin.calcBytesInMegaBytes(2097152) < 1).toBeFalsy()

describe "quota mysql", ->

  beforeEach ->
    plugin = rewire("./quota_mysql.js");
    plugin.getUserQuota = jasmine.createSpy('getUserQuota').andCallFake (connection, params, callback) ->
      callback null, {quota: 50, bytes: 1000000000}
    spyOn(plugin, "isNumeric").andCallThrough()
    spyOn(plugin, "calcBytesInMegaBytes").andCallThrough()
    params = new Address('test@test.dev')
    next = jasmine.createSpy('next')
    connection =
      relaying: false
      logdebug: () -> jasmine.createSpy('logdebug')
      loginfo: () -> jasmine.createSpy('loginfo')
      logwarn: () -> jasmine.createSpy('logwarn')
      logerror: () -> jasmine.createSpy('logerror')
      logalert: () -> jasmine.createSpy('logalert')

  it "should only call next without address", ->
    plugin.quota_mysql next, connection

    expect(next).toHaveBeenCalledWith()
    expect(plugin.getUserQuota.callCount).toBe(0)

  it "should only call next when connection is relaying", ->
    connection.relaying = true
    plugin.quota_mysql next, connection, params

    expect(next).toHaveBeenCalledWith()
    expect(plugin.getUserQuota.callCount).toBe(0)

  it "should call getUserQuota with correct params", ->
    plugin.quota_mysql next, connection, params

    expect(plugin.getUserQuota).toHaveBeenCalledWith(connection, params, jasmine.any(Function))

  it "should call next on query error", ->
    plugin.getUserQuota.andCallFake (connection, params, callback) ->
      callback new Error 'some errors for everyone'

    plugin.quota_mysql next, connection, params
    expect(next).toHaveBeenCalledWith()

  it "should call next when empty query result", ->
    plugin.getUserQuota.andCallFake (connection, params, callback) ->
      callback null, null

    plugin.quota_mysql next, connection, params
    expect(next).toHaveBeenCalledWith()

  it "should call next when result has no quota property", ->
    plugin.getUserQuota.andCallFake (connection, params, callback) ->
      callback null, {bytes: 1000}

    plugin.quota_mysql next, connection, params
    expect(next).toHaveBeenCalledWith()

  it "should call next when result has no bytes property", ->
    plugin.getUserQuota.andCallFake (connection, params, callback) ->
      callback null, {quota: 10}

    plugin.quota_mysql next, connection, params
    expect(next).toHaveBeenCalledWith()

  it "should call isNumeric for two values", ->
    plugin.calcBytesInMegaBytes.andCallFake () -> true

    plugin.quota_mysql next, connection, params
    expect(plugin.isNumeric.callCount).toBe(2)
    expect(plugin.isNumeric).toHaveBeenCalledWith(50)
    expect(plugin.isNumeric).toHaveBeenCalledWith(1000000000)

  it "should call calc bytes in megabytes", ->
    plugin.quota_mysql next, connection, params

    expect(plugin.calcBytesInMegaBytes).toHaveBeenCalledWith(1000000000)

  it "should call next when quota and bytes are not numeric", ->
    plugin.getUserQuota = jasmine.createSpy('getUserQuota').andCallFake (connection, params, callback) ->
      callback null, {quota: 'abs', bytes: "xof"}

    plugin.quota_mysql next, connection, params
    expect(next).toHaveBeenCalledWith()

  it "should next with deny and message", ->
    plugin.quota_mysql next, connection, params
    expect(next).toHaveBeenCalledWith(DENY, DSN.mbox_full())

  it "should call next when quota not reached", ->
    plugin.getUserQuota.andCallFake (connection, params, callback) ->
      callback null, {quota: 50000, bytes: 1000000000}

    plugin.quota_mysql next, connection, params
    expect(next).toHaveBeenCalledWith()


describe "get user quota", ->

  beforeEach ->
    plugin = rewire("./quota_mysql.js");
    plugin.config =
      get: jasmine.createSpy('get').andCallFake () ->
        main:
          query: 'SELECT * FROM quota WHERE address = "%u"'
    connection =
      server:
        notes:
          mysql_provider:
            query: jasmine.createSpy('mysql_provider.query').andCallFake (query, callback) ->
              callback null, [{quota: 10, bytes: 1000}]
      logdebug: () -> jasmine.createSpy('logdebug')
      loginfo: () -> jasmine.createSpy('loginfo')
      logwarn: () -> jasmine.createSpy('logwarn')

  it "should fail when mysql provider is not initialized", (done) ->
    delete connection.server.notes.mysql_provider

    plugin.getUserQuota connection, new Address('test@test.dev'), (err) ->
      expect(err).toEqual(new Error 'mysql provider seems mot initialized')
      done()

  it "should fail when no address object is given", (done) ->
    plugin.getUserQuota connection, {}, (err) ->
      expect(err).toEqual(new Error 'Invalid address parameter')
      done()

  it "should load config", (done) ->
    plugin.getUserQuota connection, new Address('test@test.dev'), () ->
      expect(plugin.config.get).toHaveBeenCalledWith('quota_mysql.ini', 'ini');
      done()

  it "should use configured query", (done) ->
    expectedQuery = 'SELECT * FROM quota WHERE address = "test@test.dev"';

    plugin.getUserQuota connection, new Address('test@test.dev'), () ->
      expect(connection.server.notes.mysql_provider.query).toHaveBeenCalledWith(expectedQuery ,jasmine.any(Function));
      done()

  it "should replace domain, host and email in query string", (done) ->
    expectedQuery = 'domain: "test.dev", user: "test", email: "test@test.dev"';
    plugin.config.get.andCallFake () ->
      main:
        query: 'domain: "%d", user: "%n", email: "%u"'

    plugin.getUserQuota connection, new Address('test@test.dev'), () ->
      expect(connection.server.notes.mysql_provider.query).toHaveBeenCalledWith(expectedQuery ,jasmine.any(Function));
      done()

  it "should fail when query is not configured", (done) ->
    plugin.config.get = jasmine.createSpy('get').andCallFake () -> return {main:{}}

    plugin.getUserQuota connection, new Address('test@test.dev'), (err) ->
      expect(err).toBeTruthy();
      done()

  it "should fail on query error", (done) ->
    error = new Error 'fail callback'

    connection.server.notes.mysql_provider.query = jasmine.createSpy('mysql_provider')
    .andCallFake (query, callback) -> return callback error

    plugin.getUserQuota connection, new Address('test@test.dev'), (err) ->
      expect(err).toBe(error)
      done()

  it "should call callback with correct results", (done) ->
    plugin.getUserQuota connection, new Address('test@test.dev'), (err, result) ->
      expect(result).toEqual({quota: 10, bytes: 1000})
      done()

  it "should return empty query result", (done) ->
    connection.server.notes.mysql_provider.query = jasmine.createSpy('mysql_provider')
    .andCallFake (query, callback) -> return callback null, null

    plugin.getUserQuota connection, new Address('test@test.dev'), (err, result) ->
      expect(result).toBe(null)
      done()
