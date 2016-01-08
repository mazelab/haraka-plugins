rewire = require 'rewire'
Address = require('./address.js').Address;

# set haraka globals
constants = require './constants.js'
global.OK = constants.ok
global.CONT = constants.cont
global.DENYSOFT = constants.denysoft

plugin =
connection =
params =
next =

describe "register", ->

  beforeEach ->
    plugin = rewire("./rcpt_to.dovecot_deliverable.js");
    plugin.register_hook = jasmine.createSpy('register_hook')
    plugin.load_cfg_ini = jasmine.createSpy('load_cfg_ini')

  it 'should register hook for rcpt with check_rcpt_on_dovecot', ->
    plugin.register();
    expect(plugin.register_hook).toHaveBeenCalledWith('rcpt', 'check_rcpt_on_dovecot');

  it "should call load cfg ini", ->
    plugin.register();
    expect(plugin.load_cfg_ini).toHaveBeenCalled();


describe "load cfg ini", ->

  beforeEach ->
    config =

    plugin = rewire "./rcpt_to.dovecot_deliverable.js"
    plugin.config =
      get: jasmine.createSpy('get').andCallFake () ->
        main:
          path: "/var/run/dovecot/auth-master"
          host: "127.0.0.1"
          port: "8998"

  it "should call plugin.config.get with correct parameter", ->
    plugin.load_cfg_ini()
    expect(plugin.config.get).toHaveBeenCalledWith('rcpt_to.dovecot_deliverable.ini', jasmine.any(Function))

  it "should set cfg property", ->
    config =
      main:
        path: "/var/run/dovecot/auth-master"
        host: "127.0.0.1"
        port: "8998"

    plugin.config.get.andCallFake () -> config

    plugin.load_cfg_ini()
    expect(plugin.cfg).toBe(config)


describe "check rcpt on dovecot", ->

  beforeEach ->
    plugin = rewire "./rcpt_to.dovecot_deliverable.js"
    plugin.get_dovecot_response = jasmine.createSpy('get_dovecot_response').andCallFake (connection, address, callback) -> callback null, [OK, 'Mailbox found.']
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

  it "should call 'check_rcpt_on_dovecot' with correct parameters", ->
    plugin.check_rcpt_on_dovecot next, connection, params
    expect(plugin.get_dovecot_response).toHaveBeenCalledWith(connection, params[0].address(), jasmine.any(Function))

  it "should not call next when connection.transaction or params is missing", ->
    plugin.check_rcpt_on_dovecot next, connection, []
    expect(next.callCount).toBe(0)

    connection.transaction = null

    plugin.check_rcpt_on_dovecot next, connection, params
    expect(next.callCount).toBe(0)

  it "should call next(OK) when connection.relaying and local_sender", ->
    connection.relaying = true
    connection.transaction.notes.local_sender = true

    plugin.check_rcpt_on_dovecot next, connection, params
    expect(next).toHaveBeenCalledWith(OK)

  it "should not call get_dovecot_response when connection.relaying and local_sender", ->
    connection.relaying = true
    connection.transaction.notes.local_sender = true

    plugin.check_rcpt_on_dovecot next, connection, params
    expect(plugin.get_dovecot_response.callCount).toBe(0)

  it "should call next when when either connection.relaying or local_sender", ->
    plugin.get_dovecot_response.andCallFake (connection, address, callback) -> callback null, null

    connection.relaying = true
    connection.transaction.notes.local_sender = false

    plugin.check_rcpt_on_dovecot next, connection, params
    expect(next).toHaveBeenCalledWith()

    connection.relaying = false
    connection.transaction.notes.local_sender = true

    plugin.check_rcpt_on_dovecot next, connection, params
    expect(next).toHaveBeenCalledWith()

  it "should call next when 'get_dovecot_response' fails", ->
    plugin.get_dovecot_response.andCallFake (connection, address, callback) -> callback new Error 'totally failed'

    plugin.check_rcpt_on_dovecot(next, connection, params);
    expect(next).toHaveBeenCalledWith();

  it "should call next(OK) when in_mysql result is ok", ->
    plugin.get_dovecot_response.andCallFake (connection, address, callback) -> callback null, [OK, 'Mailbox found.']

    plugin.check_rcpt_on_dovecot next, connection, params
    expect(next).toHaveBeenCalledWith(OK)

  it "should call next when in_mysql result is null", ->
    plugin.get_dovecot_response.andCallFake (connection, address, callback) -> callback null, null

    plugin.check_rcpt_on_dovecot next, connection, params
    expect(next).toHaveBeenCalledWith()

  it "should call next when in_mysql result is empty array", ->
    plugin.get_dovecot_response.andCallFake (connection, address, callback) -> callback null, []

    plugin.check_rcpt_on_dovecot next, connection, params
    expect(next).toHaveBeenCalledWith()

  it "should call next when in_mysql result is not ok", ->
    plugin.get_dovecot_response.andCallFake (connection, address, callback) -> callback null, [undefined, 'Mailbox not found.']

    plugin.check_rcpt_on_dovecot next, connection, params
    expect(next).toHaveBeenCalledWith()


describe "check dovecot response", ->

  beforeEach ->
    plugin = rewire "./rcpt_to.dovecot_deliverable.js"

  it "should return OK", ->
    result = plugin.check_dovecot_response('USER\t1\ttest@test.dev\tmaildir=/data/test.dev/peter\tuid=8\tgid=12\tquota_rule=*:storage=1M\n')
    expect(result).toEqual([OK, 'Mailbox found.'])

  it "should return cont", ->
    result = plugin.check_dovecot_response('VERSION\t1\t1\nSPID\t78\n')
    expect(result).toEqual([CONT, 'Send now username to check process.'])

  it "should return denysoft", ->
    result = plugin.check_dovecot_response('FAIL\t1\t1\totally not my fault\n')
    expect(result).toEqual([DENYSOFT, 'Temporarily undeliverable: internal communication broken'])

  it "should return NOT FOUND", ->
    result = plugin.check_dovecot_response()
    expect(result).toEqual([undefined, 'Mailbox not found.'])

    result = plugin.check_dovecot_response('Unknown')
    expect(result).toEqual([undefined, 'Mailbox not found.'])


describe "get dovecot response", ->
  netMock = null

  beforeEach ->
    plugin = rewire "./rcpt_to.dovecot_deliverable.js"
    spyOn(plugin, "check_dovecot_response").andCallThrough()

    netMock =
      onData: ->
      onEnd: ->
      onError: ->
      write: (data) ->
        this.onData new Buffer('USER\t1\ttest@test.dev\tmaildir=/data/test.dev/peter\tuid=8\tgid=12\tquota_rule=*:storage=1M\n')
      end: (end) ->
        this.onEnd()
      on: (event, action) ->
        this.onData = action if event == 'data'
        this.onEnd = action if event == 'end'
        this.onError = action if event == 'error'

    plugin.__set__ 'net',
      connect: jasmine.createSpy('net.connect').andCallFake (options, listener) ->
        listener() if listener
        setTimeout () ->
          netMock.onData new Buffer('VERSION\t1\t1\nSPID\t78\n')
        , 100
        netMock
    plugin.cfg =
        main:
          path: "/var/run/dovecot/auth-master"
          host: "127.0.0.1"
          port: "8998"
    connection =
      transaction:
        notes: {}
        results:
          add: jasmine.createSpy('txn.results.add')
      logdebug: () -> jasmine.createSpy('logdebug')
      logprotocol: () -> jasmine.createSpy('logprotocol')
      loginfo: () -> jasmine.createSpy('loginfo')
      logwarn: () -> jasmine.createSpy('logwarn')


  it "should call callback with OK ", (done) ->
    plugin.get_dovecot_response connection, 'test@test.dev', (err, result) ->
      expect(result).toEqual [OK, 'Mailbox found.']
      done()

  it "should call check_dovecot_response with correct params", (done) ->
    plugin.get_dovecot_response connection, 'test@test.dev', ->
      expect(plugin.check_dovecot_response).toHaveBeenCalledWith('VERSION\t1\t1\nSPID\t78\n')
      expect(plugin.check_dovecot_response).toHaveBeenCalledWith('USER\t1\ttest@test.dev\tmaildir=/data/test.dev/peter\tuid=8\tgid=12\tquota_rule=*:storage=1M\n')
      done()

  it "should call connect with correct params", (done) ->
    plugin.get_dovecot_response connection, 'test@test.dev',->
      expect(plugin.__get__('net').connect).toHaveBeenCalledWith(jasmine.any(Object), jasmine.any(Function))
      done()

  it "should call connect with path option", (done) ->
    plugin.get_dovecot_response connection, 'test@test.dev',->
      expect(plugin.__get__('net').connect).toHaveBeenCalledWith({path: "/var/run/dovecot/auth-master"}, jasmine.any(Function))
      done()

  it "should call connect with host and port option", (done) ->
    plugin.cfg =
      main:
        host: "127.0.0.1"
        port: "8998"

    plugin.get_dovecot_response connection, 'test@test.dev',->
      expect(plugin.__get__('net').connect).toHaveBeenCalledWith({host: "127.0.0.1", port: "8998"}, jasmine.any(Function))
      done()

  it "should fail when connect options are missing", (done) ->
    plugin.cfg =
      main: {}

    plugin.get_dovecot_response connection, 'test@test.dev', (err)->
      expect(err).toBeTruthy();
      done()
