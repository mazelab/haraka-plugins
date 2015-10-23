var mysql = require('mysql');
var logger = require('./logger.js');

var connection = null;

exports.hook_init_master = function (callback, server) {
    server.loginfo(exports, 'init mysql provider');
    server.notes["mysql_provider"] = exports;
    callback();
};

exports.disconnect = function() {
    if (connection) {
        logger.logdebug(exports, 'reseting mysql connection');
        connection.end();
    }
    connection = null;
};

exports.connect = function (callback) {
    if (connection) return callback(null, connection);

    var cfg = this.config.get('mysql_provider.ini', 'ini').main || {};
    if (!cfg.host) cfg.host = "localhost";
    if (!cfg.port) cfg.port = "3006";
    if (!cfg.database) cfg.database = "";

    logger.logdebug(exports,
        'MySQL host="' + cfg.host + '"' +
        ' port="' + cfg.port + '"' +
        ' user="' + cfg.user + '"' +
        ' database="' + cfg.database + '"');

    var conn = mysql.createConnection({
        host: cfg.host || '',
        port: cfg.port || '',
        charset: cfg.charset || '',
        user: cfg.user || '',
        password: cfg.password || '',
        database: cfg.database || ''
    });
    conn.connect(function (err) {
        if (err) return callback(err);

        // reset connection on error
        conn.on('error', function (err) {
            logger.logalert(exports, new Date() + ' mysql connection error: ' + err.message);
            exports.disconnect();
        });

        connection = conn;
        return callback(null, conn);
    });
};

// see mysql query documentation -> params are resolved there
exports.query = function(query, values, callback) {
    exports.connect(function(err, connection) {
        if(err) return callback(err);
        connection.query(query, values, callback);
    });
};
