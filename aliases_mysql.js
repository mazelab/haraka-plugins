var mysql = require('mysql');
var Address = require('./address.js').Address;

exports.register = function () {
    this.inherits("queue/discard");
    this.register_hook("rcpt", "aliases_mysql");
};

exports.aliases_mysql = function (next, connection, params) {
    var rcpt = params && params[0].address();
    if (!connection.transaction.notes.local_sender) {
        return next()
    }

    this.getAliasByEmail(connection, rcpt, function (error, result) {
        if (error) {
            connection.logdebug(exports, "Error: " + error.message);
            return next();
        }

        switch (result.action.toLowerCase()) {
            case "drop":
                exports.drop(connection, rcpt);
                next(DENY);
                break;
            case "alias":
                exports.alias(connection, rcpt, result);
                next(OK);
                break;
            default:
                connection.loginfo(exports, "unknown action: " + result.action);
                next()
        }
    });
};

exports.getAliasByEmail = function (connection, email, callback) {
    if(!connection.server.notes.mysql_provider) return callback(new Error('mysql provider seems mot initialized'));

    var cfg = this.config.get('aliases_mysql.ini', 'ini').main || {};
    if (!cfg.query) cfg.query = 'SELECT address, action, aliases FROM forwarder WHERE address = "%u"';

    var query = cfg.query.replace(/%u/g, email);
    connection.server.notes.mysql_provider.query(query, function(err, result) {
        if (err) return callback(err);
        if (!result[0] || result[0].address !== email) {
            return callback(new Error("No alias entry for " + email));
        }
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
