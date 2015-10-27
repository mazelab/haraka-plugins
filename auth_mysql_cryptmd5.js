var net_utils = require('./net_utils');
var cryptmd5 = require("./cryptmd5.js");
var Address = require("./address.js").Address;

exports.register = function() {
    this.inherits('auth/auth_base');
};

exports.hook_capabilities = function(next, connection) {
    // Do not allow AUTH unless private IP or encrypted
    if (!net_utils.is_rfc1918(connection.remote_ip) && !connection.using_tls) {
        return next();
    }

    var methods = ["PLAIN", "LOGIN"];
    connection.capabilities.push('AUTH ' + methods.join(' '));
    connection.notes.allowed_auth_methods = methods;

    return next();
};

exports.get_plain_passwd = function(connection, user, callback) {
    if (!connection.server.notes.mysql_provider) return callback(new Error('mysql provider seems mot initialized'));

    try { // supports only full email addresses as user for full query flexibility
        var address = new Address(user);
    } catch (e) {
        connection.logdebug(exports, 'auth_mysql_cryptmd5 only accepts complete email as login user: ' + user);
        return callback(null, null);
    }

    var cfg = this.config.get('auth_mysql_cryptmd5.ini', 'ini').main || {};
    if (!cfg.query) return callback(new Error('no query configured'));

    var query = cfg.query.replace(/%d/g, address.host).replace(/%n/g, address.user).replace(/%u/g, address.address());

    connection.logdebug(exports, "exec query: " + query);
    connection.server.notes.mysql_provider.query(query, function (err, result) {
        if (err) return callback(err);
        if (!result || !result[0]|| !result[0].password) return callback(null, null);
        callback(null, result[0].password);
    });
};

exports.check_plain_passwd = function (connection, user, passwd, cb) {
    this.get_plain_passwd(connection, user, function (err, cryptPasswd) {
        if (err || !cryptPasswd) {
            if (err && err.message) connection.logdebug(exports, "Error: " + err.message);
            return cb(false);
        }

        var offset = cryptPasswd.indexOf("$", 3);     // find end of the salt, skip hash based identification
        var pwSalt = cryptPasswd.substr(3, (offset -3));
        if (offset == -1 || ! pwSalt) return cb(false);

        var hashed = cryptmd5.cryptMD5(passwd, pwSalt);
        if (hashed === cryptPasswd) return cb(true);

        return cb(false);
    });
};