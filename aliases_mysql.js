var mysql = require('mysql');
var Address = require('./address.js').Address;

exports.register = function () {
    this.inherits("queue/discard");
    this.register_hook("rcpt", "aliases_mysql");
};

exports.aliases_mysql = function (next, connection, params) {
    //@todo why connection.transaction.notes.local_sender ???
    //if (!connection.transaction.notes.local_sender || !params || !params[0]) return next();
    if (!params || !params[0]) return next();

    var address = params[0];
    this.getAliasByEmail(connection, address, function (error, result) {
        if (error || !result || !result.action || !result.address || result.address !== address.address()) {
            if (error) connection.logdebug(exports, "Error: " + error.message);
            return next();
        }

        switch (result.action.toLowerCase()) {
            case "drop":
                exports.drop(connection, address.address());
                next(DENY);
                break;
            case "alias":
                exports.alias(connection, address.address(), result);
                next(OK);
                break;
            default:
                connection.logwarn(exports, "unknown action: " + result.action);
                next();
        }
    });
};

exports.getAliasByEmail = function (connection, address, callback) {
    if (!connection.server.notes.mysql_provider) return callback(new Error('mysql provider seems mot initialized'));

    var cfg = this.config.get('aliases_mysql.ini', 'ini').main || {};
    if (!cfg.query) return callback(new Error('no query configured'));

    var query = cfg.query.replace(/%d/g, address.host).replace(/%n/g, address.user).replace(/%u/g, address.address());

    connection.logdebug(exports, "exec query: " + query);

    connection.server.notes.mysql_provider.query(query, function (err, result) {
        if (err) return callback(err);
        if (!result || !result[0]) return callback(null, null);
        return callback(null, result[0]);
    });
};

exports.drop = function (connection, rcpt) {
    connection.logdebug(exports, "marking " + rcpt + " for drop");
    connection.transaction.notes.discard = true;
};

exports.alias = function (connection, rcpt, alias) {
    if (alias === null || !alias.aliases || alias.aliases.length === 0) {
        connection.loginfo(exports, 'alias failed for ' + rcpt + ', no "to" field in alias config');
        return false;
    }

    connection.transaction.rcpt_to.pop();
    connection.relaying = true;

    var aliases = alias.aliases.split("|");
    for (var index = 0; index < aliases.length; index++) {
        connection.logdebug(exports, "aliasing " + rcpt + " to " + aliases[index]);
        connection.transaction.rcpt_to.push(new Address('<' + aliases[index] + '>'));
    }
};
