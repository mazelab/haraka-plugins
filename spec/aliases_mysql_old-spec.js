var rewire = require("rewire");
var plugin, connection, config, email,
  address = require("./address.js");
var noop = function(){};
var query = {
  query : function(query, object, callback){
    callback.call(null, null, [GLOBAL.forwarder || forwarder]);
  }
};

//describe("aliases mysql", function(){
//
//  beforeEach(function() {
//    email  = this.email;
//    config = this.config;
//    plugin = rewire("./aliases_mysql.js");
//    plugin.__set__("exports.mysql", {});
//    plugin.__set__("exports.config", {
//      get:function(){
//        return {main: config}
//      }});
//    connection = this.connection;
//
//    GLOBAL.forwarder = {address: email.address(), action: "drop"};
//    GLOBAL.server.notes.aliases_mysql = {
//      config: {
//        main: config
//      },
//      pool: {
//        connect: function(callback){
//          callback(null, query);
//        }
//      }
//    };
//  });
//
//  it("should call the 'init_mysql' with same input connection", function(){
//    spyOn(plugin, "init_mysql").and.callThrough();
//    plugin.aliases_mysql(noop, connection, [email]);
//    expect(plugin.init_mysql).toHaveBeenCalledWith(connection);
//  });
//
//  it("should save sql configuration in the global.server variable", function(){
//    GLOBAL.server.notes.aliases_mysql = null;
//
//    spyOn(plugin, "init_mysql").and.callThrough();
//    plugin.aliases_mysql(noop, connection, [email]);
//
//    expect(GLOBAL.server.notes.aliases_mysql).toBeDefined();
//    expect(GLOBAL.server.notes.aliases_mysql.config.main).toBe(config);
//  });
//
//  it("should call 'get_forwarder_by_email' method", function(){
//    spyOn(plugin, "get_forwarder_by_email").and.callThrough();
//    plugin.aliases_mysql(noop, connection, [email]);
//
//    expect(plugin.get_forwarder_by_email).toHaveBeenCalledWith(connection, email.address(), jasmine.any(Function));
//  });
//
//  it("should call 'drop' method", function(){
//    spyOn(plugin, "drop").and.callThrough();
//    plugin.aliases_mysql(noop, connection, [email]);
//
//    expect(plugin.drop).toHaveBeenCalled();
//    expect(plugin.drop.calls.count()).toEqual(1);
//  });
//
//  it("should call 'drop' method and not the forwarding method 'alias'", function(){
//    spyOn(plugin, "alias").and.callThrough();
//    plugin.aliases_mysql(noop, connection, [email]);
//
//    expect(plugin.alias).not.toHaveBeenCalled();
//  });
//
//  it("should drop the email and marked in transaction notes", function(){
//    spyOn(plugin, "drop").and.callThrough();
//    plugin.aliases_mysql(noop, connection, [email]);
//
//    expect(connection.transaction.notes).toBeDefined();
//    expect(connection.transaction.notes.discard).toBe(true);
//  });
//
//  it("should drop the incoming address", function(){
//    spyOn(plugin, "drop").and.callThrough();
//    plugin.aliases_mysql(noop, connection, [email]);
//
//    expect(plugin.drop.calls.argsFor(0)).toEqual([connection, email.address()]);
//  });
//
//  it("should call 'alias' method", function(){
//    global.forwarder = {address: email.address(), action: "alias"};
//
//    spyOn(plugin, "alias").and.callThrough();
//    plugin.aliases_mysql(noop, connection, [email]);
//
//    expect(plugin.alias).toHaveBeenCalledWith(connection, email.address(), global.forwarder);
//    expect(plugin.alias.calls.count()).toEqual(1);
//  });
//
//  it("should call 'alias' and not the 'drop' method when forwarder action changed", function(){
//    global.forwarder = {address: email.address(), action: "alias"};
//
//    spyOn(plugin, "drop").and.callThrough();
//    plugin.aliases_mysql(noop, connection, [email]);
//
//    expect(plugin.drop).not.toHaveBeenCalled();
//  });
//
//  it("should not be relaying when none forwarder aliases exists", function(){
//    global.forwarder = {address: email.address(), action: "alias"};
//
//    spyOn(plugin, "alias").and.callThrough();
//    plugin.aliases_mysql(noop, connection, [email]);
//
//    expect(connection.relaying).toBeUndefined();
//    expect(connection.relaying).toBeFalsy();
//  });
//
//  it("should be relaying the forwarder alias and marked in the connection", function(){
//    global.forwarder = {address: email.address(), action: "alias", aliases: "barz@quaz"};
//
//    spyOn(plugin, "alias").and.callThrough();
//    plugin.aliases_mysql(noop, connection, [email]);
//
//    expect(connection.relaying).toBeTruthy();
//  });
//
//  it("should be relaying the two given forwarder aliases", function(){
//    global.forwarder = {address: email.address(), action: "alias", aliases: "foo@quaz|baz@quaz"};
//
//    spyOn(plugin, "alias").and.callThrough();
//    plugin.aliases_mysql(noop, connection, [email]);
//
//    expect(connection.transaction.rcpt_to).toMatch(/foo@quaz/);
//    expect(connection.transaction.rcpt_to.length).toBe(2);
//  });
//
//});