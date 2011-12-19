
# Common Environment settings
# ===========================

CFramework = require './framework'

# Virtual Hosts Configuration

CFramework::configure 'vhosts',
	'localhost':
		path: 'app'
		redis: 
			sessionStore: 0
			cacheStore: 1
		mysql: {}

# Common Database configuration. Overridden by each of the
# database configuration directives

CFramework::configure 'common_config'
	'redis':
		host: 'localhost'
		port: 6379
	'mysql':
		host: 'localhost'
		port: 3306
		user: 'root'
		password: 'passme'
		database: 'test_db'
		debug: off

# Mailer configuration
	
CFramework::configure 'mailer', 'sendmail'

module.exports = CFramework