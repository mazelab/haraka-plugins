//'use strict';

/**
 * original code from https://github.com/Dexus/haraka-plugin-dovecot
 *
 * changes:
 * - removed mail hook
 * - fixed config loading
 * - added some config checks
 * - changed rcpt hook workflow
 */

var net = require('net');

exports.register = function () {
  var plugin = this;
  plugin.register_hook('rcpt', 'check_rcpt_on_dovecot');
  plugin.load_cfg_ini()
};

exports.load_cfg_ini = function () {
  var plugin = this;
  plugin.cfg = plugin.config.get(
    'rcpt_to.dovecot_deliverable.ini',
    function () {
      plugin.load_cfg_ini();
    });
};

exports.check_rcpt_on_dovecot = function (next, connection, params) {
  var plugin = this;
  var txn = connection.transaction;
  if (!txn || !params || !params[0]) {
    return;
  }

  // a client with relaying privileges is sending from a local domain.
  // Any RCPT is acceptable.
  if (connection.relaying && txn.notes.local_sender) {
    txn.results.add(plugin, {pass: "relaying local_sender"});
    return next(OK);
  }

  plugin.get_dovecot_response(connection, params[0].address(), function (err, result) {
    if (err) {
      txn.results.add(plugin, {err: err});
      return next();
    }

    if (result && result[0] === OK) {
      txn.results.add(plugin, {
        pass: "rcpt." + result[1]
      });
      return next(OK);
    }

    // no need to DENY[SOFT] for invalid addresses. If no rcpt_to.* plugin
    // returns OK, then the address is not accepted.
    txn.results.add(plugin, {msg: "rcpt!local"});
    return next();
  });
};

exports.get_dovecot_response = function (connection, email, cb) {
  var plugin = this;
  var options = {};
  var result = [];

  if (plugin.cfg.main.path) {
    options.path = plugin.cfg.main.path;
  } else {
    if (plugin.cfg.main.host) {
      options.host = plugin.cfg.main.host;
    }
    if (plugin.cfg.main.port) {
      options.port = plugin.cfg.main.port;
    }
  }

  if (!options.path && (!options.host || !options.port)) return cb(new Error('missing dovecot connection config'));

  connection.logdebug(plugin, "checking " + email);
  var client = net.connect(options,
    function () { //'connect' listener
      connection.logprotocol(plugin, 'connect to Dovecot auth-master:' + JSON.stringify(options));
    }
  );

  client.on('data', function (chunk) {
    connection.logprotocol(plugin, 'BODY: ' + chunk);
    var arr = exports.check_dovecot_response(chunk.toString());

    if (arr[0] != CONT) {
      result = [null, arr];
      return client.end();
    }

    var send_data = 'VERSION\t1\t0\n' +
      'USER\t1\t' + email.replace("@", "\@") + '\tservice=smtp\n';

    client.write(send_data);
  });

  client.on('error', function (e) {
    result = [e];
    client.end();
  });

  client.on('end', function () {
    connection.logprotocol(plugin, 'closed connect to Dovecot auth-master');
    cb.apply(null, result);
  });
};

exports.check_dovecot_response = function (data) {
  if (data && data.match(/^VERSION\t\d+\t/i) && data.slice(-1) === '\n') {
    return [CONT, 'Send now username to check process.'];
  } else if (data && data.match(/^USER\t1/i) && data.slice(-1) === '\n') {
    return [OK, 'Mailbox found.'];
  } else if (data && data.match(/^FAIL\t1/i) && data.slice(-1) === '\n') {
    return [DENYSOFT, 'Temporarily undeliverable: internal communication broken'];
  } else {
    return [undefined, 'Mailbox not found.'];
  }
};