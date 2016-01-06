var DSN = require('./dsn');

exports.register = function () {
    this.register_hook("rcpt_ok", "quota_mysql");
};

exports.isNumeric = function (n) {
    return !isNaN(parseFloat(n)) && isFinite(n);
};

exports.calcBytesInMegaBytes = function(bytes) {
    if (!this.isNumeric(bytes)) return null;
    return (bytes / 1048576).toFixed(1);
};

exports.quota_mysql = function (next, connection, address) {
    //only check quota on local delivery
    if (!address || connection.relaying) return next();

    this.getUserQuota(connection, address, function (err, result) {
        if (err) { // log errors and emails are still allowed
            connection.logerror(exports, "Quota error: " + err);
            return next();
        }

        if (!result || !result.quota || !result.bytes) return next(); // do nothing if no data is given

        // check that result values are numeric, skip otherwise
        if (!exports.isNumeric(result.quota) || !exports.isNumeric(result.bytes)) {
            connection.logalert(exports, "Quota of user ", address.address(), " limit=\"" + result.quota + " M\" used=\"" + result.bytes + " bytes\" is not numeric");
            return next();
        }

        connection.logdebug(exports, "Quota of user ", address.address(), " limit=\"" + result.quota + " M\" used=\"" + result.bytes + " bytes\"");

        if (exports.calcBytesInMegaBytes(result.bytes) > result.quota) {
            return next(DENY, DSN.mbox_full());
        }
        return next();
    });
};

exports.getUserQuota = function (connection, address, callback) {
    if (!connection.server.notes.mysql_provider) return callback(new Error('mysql provider seems mot initialized'));
    if (!address || address.constructor.name != "Address") return callback(new Error('Invalid address parameter'));

    var cfg = this.config.get('quota_mysql.ini', 'ini').main || {};
    if (!cfg.query) return callback(new Error('no query configured'));

    var query = cfg.query.replace(/%d/g, address.host).replace(/%n/g, address.user).replace(/%u/g, address.address());

    connection.logdebug(exports, "exec query: " + query);
    connection.server.notes.mysql_provider.query(query, function (err, result) {
        if (err) return callback(err);
        if (!result || !result[0]) return callback(null, null);
        callback(null, result[0]);
    });
};
