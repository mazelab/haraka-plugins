Haraka plugins
--------------

[![Build Status](https://travis-ci.org/mazelab/haraka-plugins.svg)](https://travis-ci.org/mazelab/haraka-plugins)

# Dovecot Modules

A collection of plugins which uses dovecot as backend.

## Dovecot deliverable rcpt to

Checks rcpt_to entries against dovecot auth-master service.
 
Original code from [https://github.com/Dexus/haraka-plugin-dovecot](https://github.com/Dexus/haraka-plugin-dovecot).

### Requirements

- dovecot auth-master process through socket or host and port

### Installation

Copy the following files into your haraka instance:

- plugins/rcpt_to.dovecot_deliverable.js > plugins/rcpt_to.dovecot_deliverable.js
- config/rcpt_to.dovecot_deliverable.ini > config/rcpt_to.dovecot_deliverable.ini

Add rcpt_to.dovecot_deliverable into config/plugins.

### Configuration config/rcpt_to.dovecot_deliverable.ini

````
path=/var/run/dovecot/auth-master
````

Path to dovecot/auth-master. When path is uncommented it is used by default and the host/port config will never be used.
default: path=/var/run/dovecot/auth-master

````
host=127.0.0.1
````

The IP address of the host running dovecot for delivery

````
port=8998
````

The TCP port dovecot is listening on, to check user against service auth -> inet_listener in your dovecot config


#### Hooks

- rcpt

# MySQL modules

A collection of plugins which use the mysql provider for haraka.

#### Example config/plugins

[maildir plugin for local delivery](https://github.com/madeingnecca/haraka-plugins)


    mysql_provider
    
    # CONNECT
    # control which IPs, rDNS hostnames, HELO hostnames, MAIL FROM addresses, and
    # RCPT TO address you accept mail from. See 'haraka -h access'.
    access
    # block mails from known bad hosts (see config/dnsbl.zones for the DNS zones queried)
    dnsbl
    
    # HELO
    # see config/helo.checks.ini for configuration
    helo.checks
    # see 'haraka -h tls' for config instructions before enabling!
    #tls
    # AUTH plugins require TLS before AUTH is advertised, see
    #     https://github.com/baudehlo/Haraka/wiki/Require-SSL-TLS
    auth/auth_mysql_cryptmd5
    
    # MAIL FROM
    # Only accept mail where the MAIL FROM domain is resolvable to an MX record
    #mail_from.is_resolvable
    
    # RCPT TO
    aliases_mysql
    rcpt_to.dovecot_deliverable
    rcpt_to.mysql
    
    # RCPT TO OK
    # Plugins that run for each accepted rcpt
    quota_mysql
    
    # DATA
    data.headers
    #spamassassin
    
    # LOCAL DELIVERY
    maildir
    
    # Disconnect client if they spew bad SMTP commands at us
    max_unrecognized_commands


#### Example Database

A generic database example: 

    table: users
    
    id | email | user | password | domain | uid | gid | gecos | homedir | maildir | bytes | quota
        
    
    table: aliases
    
    id | email | action | config


## MySQL provider

Sets reusable mysql abstraction in server.notes.mysql_provider which is available in hooks through the connection object.
Reuses created mysql connection. If the connection fails (e.g. due to disconnect) the connection resets and will be recreated on the next call.

### Requirements

- npm mysql

### Installation

Install mysql in your haraka instance:

    npm install --save mysql

Copy the following files into your haraka instance:

- plugins/mysql_provider.js > plugins/mysql_provider.js
- config/mysql_provider.ini > config/mysql_provider.ini 

Add mysql_provider into config/plugins

### Configuration config/mysql_provider.ini

Name/Ip of the mysql host:

    host=localhost

Port of the mysql service:

    port=3306
    
MySQL user login:

    user=email
    
MySQL user password:

    password=password

MySQL database name:

    database=email

MySQL used char set:

    char_set=UTF8_GENERAL_CI


### Example

    if (!connection.server.notes.mysql_provider) return callback(new Error('mysql provider seems mot initialized'));
    var mysql = connection.server.notes.mysql_provider;
    
    // just query - the connection will be created automatically  
    mysql.query(myQuery, callback);
    
    // get the mysql connection object - existing connection will be used
    mysql.connect(callback);

----

## MySQL quota

Checks quota against a mysql backend. The query can and should be configured to suit your environment. 
Please note that the plugin does not calculate the quota value. You need a different service/job for that. 
Dovecot for example can do that. It is only necessary to write the into the bytes table of the mysql backend. 

Behavior:

- If the Fields are not present the mail is accepted.

- If the Field values are not numeric the mail is accepted.

- If the used quota is greater than available quota the mail is denied.

### Requirements

- mysql provider haraka plugin

### Installation

Install the mysql provider plugin if not present.

Copy the following files into your haraka instance:

- plugins/quota_mysql.js > plugins/quota_mysql.js
- config/quota_mysql.ini > config/quota_mysql.ini 

Add quota_mysql into config/plugins.

### Configuration config/quota_mysql.ini

Mysql query Should be configured to suit your environment:

    query = SELECT quota, bytes FROM users WHERE email = '%u'
    
The query must return the fields quota (in MiB) and bytes (in B).

#### Query Replacements:

%u = entire user@domain

    SELECT quota, bytes FROM users WHERE email = '%u'
    -> SELECT quota, bytes FROM users WHERE email = 'test@test.dev'

%n = user part of user@domain

    SELECT quota, bytes FROM users WHERE user = '%n'
    -> SELECT quota, bytes FROM users WHERE user = 'test'

%d = domain part of user@domain

    SELECT quota, bytes FROM users WHERE domain = '%d'
    -> SELECT quota, bytes FROM users WHERE domain = 'test.dev'

#### Hooks

- rcpt_ok

#### Limitations

- To keep the mysql query as dynamical as it is we decided to only accept the full email as the authorization user
- The plugin does not calculate the quota value iself. So a additional service/job is necessary for that.

----

## MySQL auth cryptmd5

Enables authorization for plain and login with cram md5 passwords over a mysql backend. 
The query can and should be configured to suit your environment.
The authorization will only be enabled when using tls or using a local ip address.

### Requirements

- mysql provider haraka plugin

### Installation

Install the mysql provider plugin if not present.

Copy the following files into your haraka instance:

- plugins/auth_mysql_cryptmd5.js > plugins/auth/mysql_cryptmd5.js
- plugins/cryptmd5.js > plugins/auth/cryptmd5.js
- config/auth_mysql_cryptmd5.ini > config/auth_mysql_cryptmd5.ini

Add auth/mysql_cryptmd5 into config/plugins.

### Configuration config/auth_mysql_cryptmd5.ini

Mysql query Should be configured to suit your environment:

    query = SELECT password FROM users WHERE email = '%u'
    
The query must return the field password (cram md5).

#### Query Replacements:

%u = entire user@domain

    SELECT password FROM users WHERE email = '%u'
    -> SELECT password FROM users WHERE email = 'test@test.dev'

%n = user part of user@domain

    SELECT password FROM users WHERE user = '%n'
    -> SELECT password FROM users WHERE user = 'test'

%d = domain part of user@domain

    SELECT password FROM users WHERE domain = '%d'
    -> SELECT password FROM users WHERE domain = 'test.dev'

#### Hooks

- capabilites

----

## MySQL aliases

Checks rcpt_to entries for aliases in a mysql backend.
The query can and should be configured to suit your environment.
Aliases can be configured for different actions. 

Available actions:

- drop -> denies rcpt
- alias -> sends email to all configured aliases (config value)

### Requirements

- mysql provider haraka plugin

### Installation

Install the mysql provider plugin if not present.

Copy the following files into your haraka instance:

- plugins/aliases_mysql.js > plugins/aliases_mysql.js
- config/aliases_mysql.ini > config/aliases_mysql.ini

Add aliases_mysql into config/plugins as first rcpt to to entry (see example top).

### Configuration config/aliases_mysql.ini

Mysql query Should be configured to suit your environment:

    query = SELECT action, config FROM aliases WHERE email = '%u'
    
The query must return the fields action and config.

#### Query Replacements:

%u = entire user@domain

    SELECT action, config FROM aliases WHERE email = '%u'
    -> SELECT action, config FROM aliases WHERE email = 'test@test.dev'

%n = user part of user@domain

    SELECT action, config FROM aliases WHERE user = '%n'
    -> SELECT action, config FROM aliases WHERE user = 'test'

%d = domain part of user@domain

    SELECT action, config FROM aliases WHERE domain = '%d'
    -> SELECT action, config FROM aliases WHERE domain = 'test.dev'

### Examples

    {action: "drop", config: ""}
    -> denies rcpt

    {action: "drop", config: "test2@test.dev"}
    -> denies rcpt

    {action: "alias", config: "test2@test.dev"}
    -> sends email to test2@test.dev

    {action: "alias", config: "test2@test.dev|test3@test.dev"}
    -> sends email to test2@test.dev and test3@test.dev

#### Hooks

- rcpt

----

## MySQL rcpt to

Checks rcpt_to entries in a mysql backend. 
Accepts rcpt_to if mysql returned a value.

### Requirements

- mysql provider haraka plugin

### Installation

Install the mysql provider plugin if not present.

Copy the following files into your haraka instance:

- plugins/rcpt_to.mysql.js > plugins/rcpt_to.mysql.js
- config/rcpt_to.mysql.ini > config/rcpt_to.mysql.ini

Add rcpt_to.mysql into config/plugins.

### Configuration config/rcpt_to.mysql.ini

Mysql query Should be configured to suit your environment:

    query = SELECT email FROM users WHERE email = '%u'
    
The query must return any value. 

#### Query Replacements:

%u = entire user@domain

    query = SELECT email FROM users WHERE email = '%u'
    -> SELECT email FROM users WHERE email = 'test@test.dev'

%n = user part of user@domain

    query = SELECT email FROM users WHERE user = '%n'
    -> SELECT email FROM users WHERE user = 'test'

%d = domain part of user@domain

    query = SELECT email FROM users WHERE domain = '%d'
    -> SELECT email FROM users WHERE domain = 'test.dev'

#### Hooks

- rcpt
