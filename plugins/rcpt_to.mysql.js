exports.register = function () {
  var plugin = this;
  plugin.register_hook("rcpt", "rcpt_mysql");
  plugin.load_cfg_ini();
};

exports.load_cfg_ini = function () {
  var plugin = this;
  plugin.cfg = plugin.config.get(
    'rcpt_to.mysql.ini',
    function () {
      plugin.load_cfg_ini();
    }
  );
};

exports.rcpt_mysql = function (next, connection, params) {
  var plugin = this;
  var txn = connection.transaction;
  if (!txn || !params || !params[0]) {
    return;
  }

  connection.logdebug(plugin, "Checking if " + params[0] + " is in mysql");

  // a client with relaying privileges is sending from a local domain.
  // Any RCPT is acceptable.
  if (connection.relaying && txn.notes.local_sender) {
    txn.results.add(plugin, {pass: "relaying local_sender"});
    return next(OK);
  }

  exports.in_mysql(connection, params[0], function (err, result) {
    if (err) {
      txn.results.add(plugin, {err: err});
      return next();
    }

    if (result) {
      txn.results.add(plugin, {pass: "rcpt_to"});
      return next(OK);
    }

    // no need to DENY[SOFT] for invalid addresses. If no rcpt_to.* plugin
    // returns OK, then the address is not accepted.
    txn.results.add(plugin, {msg: "rcpt!local"});
    return next();
  });
};

exports.in_mysql = function (connection, address, callback) {
  var txn = connection.transaction;
  var plugin = this;

  if (!connection.server.notes.mysql_provider) return callback(new Error('mysql provider seems mot initialized'));
  if (!plugin.cfg.main.query) return callback(new Error('no query configured'));

  var query = plugin.cfg.main.query.replace(/%d/g, address.host).replace(/%n/g, address.user).replace(/%u/g, address.address());

  txn.results.add(plugin, {msg: "exec query: " + query});
  connection.server.notes.mysql_provider.query(query, function (err, result) {
    if (err) return callback(err);
    if (!result || !result[0]) return callback(null, null);
    callback(null, true);
  });
};