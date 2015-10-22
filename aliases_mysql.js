var mysql = require('mysql');
var Address = require('./address.js').Address;

var mysqlConnection = null;
var mysqlDefault = {
    main: {
        host: 'localhost',
        port: 3306,
        char_set: 'UTF8_GENERAL_CI',
        ssl: false,
        alias_query: "SELECT * FROM aliases WHERE email = '%u'"
    }
};

exports.register = function () {
    this.inherits("queue/discard");
    this.register_hook("rcpt", "aliases_mysql");
};

exports.aliases_mysql = function (next, connection, params) {
    var rcpt = params && params[0].address();
    if (!connection.transaction.notes.local_sender) {
        return next()
    }

    this.getAliasByEmail(connection, rcpt, function (error, forwarder) {
        if (error) {
            connection.logdebug(exports, "Error: " + error.message);
            return next();
        }

        switch (forwarder.action.toLowerCase()) {
            case "drop":
                exports.drop(connection, rcpt);
                next(DENY);
                break;
            case "alias":
                exports.alias(connection, rcpt, forwarder);
                next(OK);
                break;
            default:
                connection.loginfo(exports, "unknown action: " + forwarder.action);
                next()
        }
    });
};

exports.getAliasByEmail = function (connection, email, callback) {
    var config = this.config.get('aliases_mysql.ini', 'ini') || mysqlDefault;
    if (!config.main.alias_query) config.main.alias_query = mysqlDefault.main.alias_query;

    this.connectMysql(connection, config.main, function (err, mysqlConnection) {
        if (err) return callback(err);

        var query = config.main.alias_query.replace(/%u/g, email);
        connection.logdebug(exports, 'exec query: ' + query);
        mysqlConnection.query(query, [], function (error, result) {
            if (error) return callback(error);
            if (!result[0] || result[0].address !== email) {
                callback(new Error("No alias entry for " + email));
            }

            return callback(null, result[0]);
        });
    });
};

exports.drop = function (connection, rcpt) {
    connection.logdebug(exports, "marking " + rcpt + " for drop");
    connection.transaction.notes.discard = true;
};

exports.alias = function (connection, rcpt, forwarder) {
    if (forwarder === null || !forwarder.aliases || forwarder.aliases.length === 0) {
        connection.loginfo(exports, 'alias failed for ' + rcpt + ', no "to" field in alias config');
        return false;
    }

    connection.transaction.rcpt_to.pop();
    connection.relaying = true;

    var aliases = forwarder.aliases.split("|");
    for (var index = 0; index < aliases.length; index++) {
        connection.logdebug(exports, "aliasing " + rcpt + " to " + aliases[index]);
        connection.transaction.rcpt_to.push(new Address('<' + aliases[index] + '>'));
    }
};

exports.connectMysql = function (connection, config, callback) {
    if (mysqlConnection) return callback(null, mysqlConnection);

    var conn = mysql.createConnection({
        host: config.host || 'localhost',
        port: config.port || '3306',
        charset: config.charset || 'UTF8_GENERAL_CI',
        user: config.user,
        password: config.password,
        database: config.database
    });

    connection.logdebug(exports,
        'MySQL host="' + config.host + '"' +
        ' port="' + config.port + '"' +
        ' user="' + config.user + '"' +
        ' database="' + config.database + '"');

    conn.connect(function (err) {
        if (err) return callback(err);

        // reset connection on error
        conn.on('error', function (err) {
            connection.logdebug(exports, new Date() + ' mysql connection error: ' + err.message);
            if (mysqlConnection) {
                connection.logdebug('resetting connection');
                mysqlConnection.end();
                mysqlConnection = null;
            }
        });

        mysqlConnection = conn;
        return callback(null, mysqlConnection);
    });
};