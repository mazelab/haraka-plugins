rewire = require 'rewire'

plugin =
connection =
next =

describe "register", ->

  beforeEach ->
    plugin = rewire("./auth_mysql_cryptmd5.js");
    plugin.inherits = jasmine.createSpy('inherits')

  it 'should inherit plugin auth/auth_base', () ->
    plugin.register();
    expect(plugin.inherits).toHaveBeenCalledWith('auth/auth_base');


describe "hook capabilites", ->

  beforeEach ->
    plugin = rewire("./auth_mysql_cryptmd5.js");
    next = jasmine.createSpy('next')
    connection =
      capabilities: []
      notes:
        allowed_auth_methods: []
      using_tls: true
      remote_ip: '127.0.0.1'

  it "should call next", ->
    plugin.hook_capabilities next, connection
    expect(next).toHaveBeenCalledWith()

  it "should set plain and login as auth capabilities", ->
    plugin.hook_capabilities next, connection
    expect(connection.capabilities).toEqual(['AUTH PLAIN LOGIN'])
    expect(connection.notes.allowed_auth_methods).toEqual(['PLAIN', 'LOGIN'])

  it "should set auth when using tls", ->
    connection.using_tls = true
    connection.remote_ip = "192.203.230.10"
    plugin.hook_capabilities next, connection
    expect(connection.capabilities).toEqual(['AUTH PLAIN LOGIN'])

  it "should set auth when using local ip", ->
    connection.using_tls = false
    connection.remote_ip = '127.0.0.1'
    plugin.hook_capabilities next, connection
    expect(connection.capabilities).toEqual(['AUTH PLAIN LOGIN'])

  it "should not set auth when not using tls or using a remote ip", ->
    connection.using_tls = false
    connection.remote_ip = "192.203.230.10"
    plugin.hook_capabilities next, connection
    expect(connection.capabilities).toEqual([])


describe "get plain password", ->

  beforeEach ->
    plugin = rewire("./auth_mysql_cryptmd5.js");
    plugin.config =
      get: jasmine.createSpy('get').andCallFake () ->
        main:
          query: 'SELECT password FROM users WHERE address = "%u"'
    connection =
      server:
        notes:
          mysql_provider:
            query: jasmine.createSpy('mysql_provider.query').andCallFake (query, callback) ->
              callback null, [{password: '$1$7WINMYo6$gZJk1uRGKRprWMA0Tz90O/'}]
      logdebug: () -> jasmine.createSpy('logdebug')
      loginfo: () -> jasmine.createSpy('loginfo')

  it "should fail when mysql provider is not initialized", (done) ->
    delete connection.server.notes.mysql_provider

    plugin.get_plain_passwd connection, 'test@test.dev', (err) ->
      expect(err).toEqual(new Error 'mysql provider seems mot initialized')
      done()

  it "should return null without mysql query if user is not a full email", (done) ->
    plugin.get_plain_passwd connection, 'test', (err, result) ->
      expect(err).toBeNull()
      expect(result).toBeNull()
      done()

  it "should load config", (done) ->
    plugin.get_plain_passwd connection, 'test@test.dev', () ->
      expect(plugin.config.get).toHaveBeenCalledWith('auth_mysql_cryptmd5.ini', 'ini');
      done()

  it "should use configured query", (done) ->
    expectedQuery = 'SELECT password FROM users WHERE address = "test@test.dev"';

    plugin.get_plain_passwd connection, 'test@test.dev', () ->
      expect(connection.server.notes.mysql_provider.query).toHaveBeenCalledWith(expectedQuery ,jasmine.any(Function));
      done()

  it "should replace domain, host and email in query string", (done) ->
    expectedQuery = 'domain: "test.dev", user: "test", email: "test@test.dev"';
    plugin.config.get.andCallFake () ->
      main:
        query: 'domain: "%d", user: "%n", email: "%u"'

    plugin.get_plain_passwd connection, 'test@test.dev', () ->
      expect(connection.server.notes.mysql_provider.query).toHaveBeenCalledWith(expectedQuery ,jasmine.any(Function));
      done()

  it "should fail when query is not configured", (done) ->
    plugin.config.get = jasmine.createSpy('get').andCallFake () -> return {main:{}}

    plugin.get_plain_passwd connection, 'test@test.dev', (err) ->
      expect(err).toBeTruthy();
      done()

  it "should fail on query error", (done) ->
    error = new Error 'fail callback'

    connection.server.notes.mysql_provider.query = jasmine.createSpy('mysql_provider')
    .andCallFake (query, callback) -> return callback error

    plugin.get_plain_passwd connection, 'test@test.dev', (err) ->
      expect(err).toBe(error)
      done()

  it "should call callback with correct results", (done) ->
    plugin.get_plain_passwd connection, 'test@test.dev', (err, result) ->
      expect(result).toEqual('$1$7WINMYo6$gZJk1uRGKRprWMA0Tz90O/')
      done()

  it "should return null on empty query result", (done) ->
    connection.server.notes.mysql_provider.query = jasmine.createSpy('mysql_provider')
    .andCallFake (query, callback) -> return callback null, null

    plugin.get_plain_passwd connection, 'test@test.dev', (err, result) ->
      expect(result).toBe(null)
      done()

  it "should return null when result has no password property", (done) ->
    connection.server.notes.mysql_provider.query = jasmine.createSpy('mysql_provider')
    .andCallFake (query, callback) -> return callback null, {some: "thing"}

    plugin.get_plain_passwd connection, 'test@test.dev', (err, result) ->
      expect(result).toBe(null)
      done()


describe "check plain password", ->

  beforeEach ->
    plugin = rewire("./auth_mysql_cryptmd5.js");
    spyOn(plugin, 'get_plain_passwd').andCallFake (connection, user, callback) ->
      callback null, '$1$7WINMYo6$gZJk1uRGKRprWMA0Tz90O/'
    connection =
      server:
        notes: {}
      logdebug: () -> jasmine.createSpy('logdebug')
      loginfo: () -> jasmine.createSpy('loginfo')

  it "should call get plain passwd", (done) ->
    plugin.check_plain_passwd connection, 'test@test.dev', 'totallysecret', (result) ->
      expect(plugin.get_plain_passwd).toHaveBeenCalledWith(connection, 'test@test.dev', jasmine.any(Function));
      done()

  it "should fail on query error", (done) ->
    plugin.get_plain_passwd.andCallFake (connection, user, callback) ->
      callback new Error 'something came up'

    plugin.check_plain_passwd connection, 'test@test.dev', 'totallysecret', (result) ->
      expect(result).toBeFalsy()
      done()

  it "should call callback false on empty result", (done) ->
    plugin.get_plain_passwd.andCallFake (connection, user, callback) ->
      callback null, null

    plugin.check_plain_passwd connection, 'test@test.dev', 'totallysecret', (result) ->
      expect(result).toBeFalsy()
      done()

  it "should call callback false when salt could not be extracted from crypted password", (done) ->
    plugin.get_plain_passwd.andCallFake (connection, user, callback) ->
      callback null, 'sorry, i am not salty'

    plugin.check_plain_passwd connection, 'test@test.dev', 'totallysecret', (result) ->
      expect(result).toBeFalsy()
      done()

  it "should return true when password match", (done) ->
    plugin.check_plain_passwd connection, 'test@test.dev', 'totallysecret', (result) ->
      expect(result).toBeTruthy();
      done()

  it "should return false if passwords do not match", (done) ->
    plugin.check_plain_passwd connection, 'test@test.dev', 'totallydifferent', (result) ->
      expect(result).toBeFalsy()
      done()
