rewire = require 'rewire'

plugin =

describe "hook init master", ->
  server =

  beforeEach ->
    plugin = rewire("./mysql_provider.js")
    server =
      notes: {}
      loginfo: jasmine.createSpy('loginfo')

  it "should add plugin in server.notes.mysql_provider", ->
    callback = jasmine.createSpy('callback')

    plugin.hook_init_master callback, server
    expect(server.notes.mysql_provider).toBeTruthy();

  it "should call callback without parameters", ->
    callback = jasmine.createSpy('callback')

    plugin.hook_init_master callback, server
    expect(callback).toHaveBeenCalledWith();


describe "disconnect", ->

  beforeEach ->
    plugin = rewire("./mysql_provider.js")

  it "should call connection.end when connection exists", ->
    endCaller = callback = jasmine.createSpy('connection.end')

    plugin.__set__ 'connection',
      end: endCaller

    plugin.disconnect();
    expect(endCaller).toHaveBeenCalled();

  it "should set connection to null", ->
    endCaller = callback = jasmine.createSpy('connection.end')

    plugin.__set__ 'connection',
      end: endCaller

    plugin.disconnect();
    expect(plugin.__get__ 'connection').toBeNull();

  it "should do nothing when connection does not exist", ->
    plugin.disconnect();
    expect(plugin.__get__ 'connection').toBeNull();

describe "connect", ->

  beforeEach ->
    plugin = rewire("./mysql_provider.js")
    plugin.__set__ 'mysql',
      createConnection: jasmine.createSpy('createConnection').andCallFake () ->
        connect: jasmine.createSpy('connection.connect').andCallFake (callback) -> return callback null, true
        on: jasmine.createSpy('connection.on').andCallFake () ->
        end: jasmine.createSpy('connection.end').andCallFake () ->
    plugin.config =
      get: jasmine.createSpy('config.get').andCallFake () ->
        main:
          host: 'localhost',
          port: 3306,
          user: 'test'
          pass: 'test'
          database: 'test'
          char_set: 'UTF8_GENERAL_CI'

  it "should return existing mysql connection in callback", (done) ->
    plugin.__set__ 'connection', {"one": "two"}

    plugin.connect (err, connection) ->
      expect(connection).toEqual({"one": "two"})
      done()

  it "should load config with config.get 'mysql_provider.ini', 'ini'", (done) ->
    plugin.connect (err, connection) ->
      expect(plugin.config.get).toHaveBeenCalledWith('mysql_provider.ini', 'ini')
      done()

  it "should call mysql.createConnection function", (done) ->
    plugin.connect (err, connection) ->
      expect(plugin.__get__('mysql').createConnection).toHaveBeenCalled()
      done()

  it "should call connection.connect function", (done) ->
    connectCaller = jasmine.createSpy('connection.connect').andCallFake (callback) -> return callback null, true

    plugin.__set__ 'mysql',
      createConnection: jasmine.createSpy('createConnection').andCallFake () ->
        connect: connectCaller
        on: jasmine.createSpy('connection.on').andCallFake () ->

    plugin.connect (err, connection) ->
      expect(connectCaller).toHaveBeenCalled()
      done()

  it "should set on error callback on connection", (done) ->
    onErrorCaller = jasmine.createSpy('connection.on').andCallFake () ->

    plugin.__set__ 'mysql',
      createConnection: jasmine.createSpy('createConnection').andCallFake () ->
        connect: jasmine.createSpy('connection.connect').andCallFake (callback) -> return callback null, true
        on: onErrorCaller

    plugin.connect (err, connection) ->
      expect(onErrorCaller).toHaveBeenCalledWith('error', jasmine.any(Function))
      done()

  it "should use default config when no config was loaded", (done) ->
    plugin.config =
      get: jasmine.createSpy('config.get').andCallFake () -> return {main: {}}

    defaultConfig = host : 'localhost', port : '3006', charset : '', user : '', password : '', database : ''

    plugin.connect (err, connection) ->
      expect(plugin.__get__('mysql').createConnection).toHaveBeenCalledWith(defaultConfig)
      done()

  it "should fail when connection.connect fails", (done) ->
    error = new Error 'failed'
    plugin.__set__ 'mysql',
      createConnection: jasmine.createSpy('createConnection').andCallFake () ->
        connect: jasmine.createSpy('connection.connect').andCallFake (callback) -> return callback error
        on: jasmine.createSpy('connection.on').andCallFake () ->

    plugin.connect (err, connection) ->
      expect(err).toBe(error)
      done()

  it "should set connection property", (done) ->
    plugin.connect (err, connection) ->
      expect(plugin.__get__ 'connection').toMatch(jasmine.any(Object))
      done()

  it "should run connect only one time", (done) ->
    connectCaller = jasmine.createSpy('connection.connect').andCallFake (callback) -> return callback null, true

    plugin.__set__ 'mysql',
      createConnection: jasmine.createSpy('createConnection').andCallFake () ->
        connect: connectCaller
        on: jasmine.createSpy('connection.on').andCallFake () ->

    plugin.connect (err, connection) ->
      plugin.connect (err, connection) ->
        plugin.connect (err, connection) ->
          plugin.connect (err, connection) ->
            expect(connectCaller.callCount).toBe(1)
            done()

  it "should call disconnect after a mysql connection error occurred in runtime", (done) ->
    plugin.__set__ 'exports.disconnect', jasmine.createSpy('disconnect').andCallFake () ->

    plugin.__set__ 'mysql',
      createConnection: jasmine.createSpy('createConnection').andCallFake () ->
        connect: jasmine.createSpy('connect').andCallFake (callback) -> return callback null, true
        on: jasmine.createSpy('on').andCallFake (event, callback) ->
          this.onError = callback if(event == 'error')
        onError: () ->

    plugin.connect (err, connection) ->
      setTimeout ->
        connection.onError (new Error 'some error')
        expect(plugin.__get__ 'exports.disconnect').toHaveBeenCalled()
        done()
      , 100

describe "query", ->

  beforeEach () ->
    plugin = rewire("./mysql_provider.js")
    plugin.__set__ 'exports.connect', jasmine.createSpy('connect').andCallFake (callback) ->
        callback null,
          query: jasmine.createSpy('connection.query').andCallFake (query, callback) -> return callback null, ["something"]

  it "should call connect", (done) ->
    plugin.query 'query', () ->
      expect(plugin.__get__ 'exports.connect').toHaveBeenCalled();
      done()

  it "should call query", (done) ->
    queryCaller = jasmine.createSpy('connection.query').andCallFake (query, callback) -> return callback null, true

    plugin.__set__ 'exports.connect', jasmine.createSpy('connect').andCallFake (callback) ->
      callback null,
        query: queryCaller

    plugin.query 'query', () ->
      expect(queryCaller).toHaveBeenCalled();
      done()

  it "should fail on connection error", (done) ->
    error = new Error 'another error'

    plugin.__set__ 'exports.connect', jasmine.createSpy('connect').andCallFake (callback) ->
      callback error

    plugin.query 'query', (err) ->
      expect(err).toBe(error)
      done()

  it "should call callback with result", (done) ->
    plugin.query 'query', (err, result) ->
      expect(result).toEqual(["something"])
      done()
