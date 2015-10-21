rewire = require 'rewire'

describe "aliases mysql", ->

  it "should call the 'init_mysql' with same input connection", () ->

  it "should save sql configuration in the global.server variable", () ->

  it "should call 'get_forwarder_by_email' method", () ->

  it "should call 'drop' method", () ->

  it "should call 'drop' method and not the forwarding method 'alias'", () ->

  it "should drop the email and marked in transaction notes", () ->

  it "should drop the incoming address", () ->

  it "should call 'alias' method", () ->

  it "should call 'alias' and not the 'drop' method when forwarder action changed", () ->

  it "should not be relaying when none forwarder aliases exists", () ->

  it "should be relaying the forwarder alias and marked in the connection", () ->

  it "should be relaying the two given forwarder aliases", () ->
